#!/usr/bin/env bash
# Substitute placeholders and apply the Kubernetes manifests, in ADT's order:
# ZooKeeper -> Solr cluster init (chroot, urlScheme, security.json, configsets)
# -> Solr -> collections -> Liberty. The DB is SQL MI (external), so no DB manifest.
#
# Controlled deployment:
#   scripts/40-deploy-workload.sh                     everything, in order
#   scripts/40-deploy-workload.sh solr collections    only the named components (still in order)
#   DRY_RUN=true scripts/40-deploy-workload.sh ...    show what would change (kubectl diff), apply nothing
# Components: base zookeeper solr-init solr collections liberty connectors ingress
source "$(dirname "$0")/00-common.sh"
: "${ACR:?}"; : "${WI_CLIENT_ID:?}"; : "${KV:?}"; : "${TENANT_ID:?}"; : "${MI_FQDN:?}"; : "${I2_VERSION:?}"; : "${ADT_VERSION:?}"
ACR_LS="${ACR}.azurecr.io"
CONFIG_NAME="${CONFIG_NAME:-base-demo}"
DRY_RUN="${DRY_RUN:-false}"; DRY_RUN="${DRY_RUN,,}"   # pipelines pass True/False
ALL=(base zookeeper solr-init solr collections liberty connectors ingress)

selected=("$@")
[[ ${#selected[@]} -eq 0 || " ${selected[*]} " == *" all "* ]] && selected=("${ALL[@]}")
for c in "${selected[@]}"; do
  [[ " ${ALL[*]} " == *" $c "* ]] || { echo "unknown component '$c' (valid: ${ALL[*]})" >&2; exit 2; }
done
want() { [[ " ${selected[*]} " == *" $1 "* ]]; }
log "components: ${selected[*]}$([[ $DRY_RUN == true ]] && echo ' (dry run)')"

images=()
want zookeeper && images+=("i2group/i2eng-zookeeper:3.9")
{ want solr-init || want collections; } && images+=("i2group/i2-solr-init:${I2_VERSION}")
want solr && images+=("i2group/solr_redhat:${I2_VERSION}")
want liberty && images+=("i2group/liberty_configured_redhat:${CONFIG_NAME}-${I2_VERSION}")
[[ ${#images[@]} -gt 0 ]] && require_images "${images[@]}"

aks_login

render() { sed -e "s#__ACR__#${ACR_LS}#g" -e "s#__WI_CLIENT_ID__#${WI_CLIENT_ID}#g" \
              -e "s#__KV_NAME__#${KV}#g" -e "s#__TENANT_ID__#${TENANT_ID}#g" \
              -e "s#__MI_FQDN__#${MI_FQDN}#g" -e "s#__I2_VERSION__#${I2_VERSION}#g" \
              -e "s#__ADT_VERSION__#${ADT_VERSION}#g" "$1"; }
apply() {
  local f
  for f in "$@"; do
    if [[ "$DRY_RUN" == true ]]; then
      log "diff k8s/${f}.yaml"
      render "k8s/${f}.yaml" | kubectl diff -f - || true   # exit 1 just means "differs"
    else
      render "k8s/${f}.yaml" | kubectl apply -f -
    fi
  done
}
rollout() { [[ "$DRY_RUN" == true ]] || kubectl rollout status "$1" -n "$ns" --timeout=900s; }
run_job() { # job file under k8s/jobs, job name
  if [[ "$DRY_RUN" == true ]]; then log "would re-run job $2"; return; fi
  kubectl delete job "$2" -n "$ns" --ignore-not-found
  render "k8s/jobs/$1.yaml" | kubectl apply -f -
  if ! kubectl wait --for=condition=complete "job/$2" -n "$ns" --timeout=900s; then
    kubectl logs "job/$2" -n "$ns" --tail=50 || true
    echo "job $2 did not complete - fix and re-run: scripts/40-deploy-workload.sh <component>" >&2
    exit 1
  fi
}

want base        && apply namespace secretproviderclass services
want zookeeper   && { apply zookeeper-statefulset; rollout statefulset/zookeeper; }
want solr-init   && { log "Solr cluster init in ZooKeeper"; run_job solr-zk-init-job i2-solr-zk-init; }
want solr        && { apply solr-statefulset; rollout statefulset/solr; }
want collections && { log "Solr collections"; run_job solr-collections-job i2-solr-collections; }
want liberty     && { apply liberty-deployment; rollout deployment/liberty; }
want connectors  && apply connectors-deployment
want ingress     && apply ingress
log "Done. Watch: kubectl get pods -n $ns -w   Verify: scripts/60-sanity.sh"
