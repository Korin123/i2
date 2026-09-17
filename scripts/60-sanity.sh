#!/usr/bin/env bash
# Sanity checks (Azure equivalent of the i2 sanity_tests role). Runs every check, prints
# PASS/FAIL for each and exits non-zero if any failed, so the pipeline stage fails.
# Health checks follow ADT 3.2.2 (utils/common_functions.sh): ZooKeeper AdminServer
# /commands/srvr + mntr, Solr CLUSTERSTATUS as the Solr admin, Liberty
# /api/v1/health/live as the ADT admin. Checks run inside the cluster via kubectl exec;
# passwords are read from Key Vault and passed on stdin, never on a command line.
# Needs az; kubectl, kubelogin and jq are installed if missing.
source "$(dirname "$0")/00-common.sh"
azure_outputs
: "${I2_VERSION:?}"
set +e   # a failing check must not stop the others

ACR_LS="${ACR}.azurecr.io"
COLLECTIONS=(main_index match_index1 match_index2 highlight_index chart_index vq_index recordshare_index daod_index)
DB_STEPS=(create_dba create_db_roles grant_permissions login_dbb login_i2analyze login_i2etl login_etl
          etl_sysadmin static_scripts dynamic_scripts role_i2_public role_deletion_rule)

aks_login
kv() { az keyvault secret show --vault-name "$KV" -n "$1" --query value -o tsv; }

failures=()
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1${2:+ - $2}"; failures+=("$1"); }

echo "=== pods ==="; kubectl get pods -n "$ns" -o wide
echo "=== checks ==="

# --- workloads -----------------------------------------------------------------
ready_equals() { # kind/name expected
  local ready; ready="$(kubectl get "$1" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  [[ "${ready:-0}" == "$2" ]] && pass "$1 ready ${2}/${2}" || fail "$1 ready ${ready:-0}/$2"
}
ready_equals statefulset/zookeeper 3
ready_equals statefulset/solr 2
ready_equals statefulset/liberty 2
for job in i2-solr-zk-init i2-solr-collections i2-db-init i2-match-rules; do
  [[ "$(kubectl get "job/$job" -n "$ns" -o jsonpath='{.status.succeeded}' 2>/dev/null)" == 1 ]] \
    && pass "job $job succeeded" || fail "job $job succeeded" "kubectl logs job/$job -n $ns"
done
[[ "$(kubectl get pods -n "$ns" -l app=solr -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null | tr ' ' '\n' \
    | xargs -r -I{} kubectl get node {} -o jsonpath='{.metadata.labels.workload}{"\n"}' | sort -u)" == i2-solr ]] \
  && pass "solr pods on the i2solr node pool" || fail "solr pods on the i2solr node pool"

# --- ZooKeeper (from a Solr pod, as ADT does from its Solr client) ----------------
leaders=0
for i in 0 1 2; do
  zk="zookeeper-$i.zookeeper-headless"
  srvr="$(kubectl exec -n "$ns" solr-0 -c solr -- curl -sS --fail --max-time 10 "http://$zk:8080/commands/srvr" 2>&1)"
  if [[ "$(jq -r '.error' <<<"$srvr" 2>/dev/null)" == null ]]; then pass "zookeeper-$i serving"
  else fail "zookeeper-$i serving" "$(head -c 200 <<<"$srvr")"; fi
  state="$(kubectl exec -n "$ns" solr-0 -c solr -- curl -sS --max-time 10 "http://$zk:8080/commands/mntr" 2>/dev/null \
    | jq -r '.server_state // empty' 2>/dev/null)"
  [[ "$state" == leader ]] && leaders=$((leaders + 1))
done
[[ "$leaders" == 1 ]] && pass "zookeeper ensemble has one leader" || fail "zookeeper ensemble has one leader" "found $leaders"

# --- Solr ----------------------------------------------------------------------
status="$(kv solr-admin-digest-password | kubectl exec -i -n "$ns" solr-0 -c solr -- bash -c \
  'read -r pw; curl -sS --fail --max-time 30 -u "solr:$pw" --cacert /etc/i2secrets/CA.cer \
     "https://${SOLR_HOST}:8983/solr/admin/collections?action=CLUSTERSTATUS&wt=json"' 2>&1)"
if jq -e .cluster >/dev/null 2>&1 <<<"$status"; then
  pass "solr CLUSTERSTATUS over TLS with BasicAuth"
  live="$(jq '.cluster.live_nodes | length' <<<"$status")"
  [[ "$live" == 2 ]] && pass "solr live nodes 2/2" || fail "solr live nodes $live/2"
  jq -r '.cluster.live_nodes[]' <<<"$status" | grep -qv '\.solr-headless\.' \
    && fail "solr nodes registered by pod FQDN" "$(jq -c .cluster.live_nodes <<<"$status")" \
    || pass "solr nodes registered by pod FQDN (SOLR_HOST)"
  for c in "${COLLECTIONS[@]}"; do
    # ADT pre-prod layout: 1 shard, 2 replicas, one per Solr node (placement plugin)
    summary="$(jq -r --arg c "$c" '.cluster.collections[$c].shards // empty | to_entries[] | .value.replicas | [length, ([.[] | select(.state == "active")] | length), ([.[].node_name] | unique | length)] | @tsv' <<<"$status")"
    if [[ -z "$summary" ]]; then fail "collection $c exists"; continue; fi
    bad="$(awk -F'\t' '$1 != 2 || $2 != 2 || $3 != 2' <<<"$summary")"
    if [[ -z "$bad" ]]; then pass "collection $c: 2 active replicas per shard on different nodes"
    else fail "collection $c replicas" "replicas/active/nodes per shard: $(tr '\t\n' '/ ' <<<"$summary")"; fi
  done
else
  fail "solr CLUSTERSTATUS over TLS with BasicAuth" "$(head -c 300 <<<"$status")"
fi
# Liberty's application user must be accepted too (security.json credentials)
code="$(kubectl exec -n "$ns" liberty-0 -c liberty -- bash -c \
  'curl -s -o /dev/null -w "%{http_code}" --max-time 30 -u "liberty:$(</etc/i2secrets/SOLR_HTTP_BASIC_AUTH_PASSWORD)" \
     --cacert /etc/i2secrets/CA.cer "https://solr-0.solr-headless.i2analyze.svc.cluster.local:8983/solr/main_index/admin/ping?wt=json"' 2>/dev/null)"
[[ "$code" == 200 ]] && pass "solr accepts the liberty application user" || fail "solr accepts the liberty application user" "HTTP ${code:-no response}"

# --- SQL Managed Instance ------------------------------------------------------
kubectl exec -n "$ns" liberty-0 -c liberty -- bash -c "timeout 10 bash -c '</dev/tcp/${MI_FQDN}/1433'" >/dev/null 2>&1 \
  && pass "liberty reaches ${MI_FQDN}:1433" || fail "liberty reaches ${MI_FQDN}:1433"
markers="$(kv SA_PASSWORD | kubectl run i2-sanity-sql -n "$ns" --rm -i --quiet --restart=Never \
  --image="${ACR_LS}/i2group/i2-db-init:${I2_VERSION}" \
  --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"workload":"i2-analyze"}}}' \
  --command -- bash -c "read -r pw; /opt/mssql-tools/bin/sqlcmd -N -b -S '${MI_FQDN},1433' -U i2miadmin -P \"\$pw\" -h -1 -W \
     -Q \"SET NOCOUNT ON; SELECT name FROM ISTORE.sys.extended_properties WHERE class = 0 AND name LIKE 'i2aks.%'\"" 2>&1)"
missing=()
for s in "${DB_STEPS[@]}"; do grep -qx "i2aks.$s" <<<"$markers" || missing+=("$s"); done
if [[ ${#missing[@]} == 0 ]]; then pass "ISTORE initialised (all ${#DB_STEPS[@]} db-init steps recorded)"
else fail "ISTORE initialised" "missing: ${missing[*]} $(grep -m1 -i 'error\|msg' <<<"$markers")"; fi

# --- Liberty -------------------------------------------------------------------
for pod in $(kubectl get pods -n "$ns" -l app=liberty -o jsonpath='{.items[*].metadata.name}'); do
  code="$(kv liberty-admin-password | kubectl exec -i -n "$ns" "$pod" -- bash -c \
    'read -r pw; curl -s -o /dev/null -w "%{http_code}" --max-time 30 -u "adt-admin:$pw" \
       --cacert /etc/i2secrets/CA.cer https://localhost:9443/opal/api/v1/health/live' 2>/dev/null)"
  [[ "$code" == 200 ]] && pass "$pod /opal/api/v1/health/live" || fail "$pod /opal/api/v1/health/live" "HTTP ${code:-no response}"
done

echo "=== summary ==="
if [[ ${#failures[@]} == 0 ]]; then
  echo "All checks passed."
else
  echo "${#failures[@]} check(s) failed:"; printf '  - %s\n' "${failures[@]}"
  exit 1
fi
