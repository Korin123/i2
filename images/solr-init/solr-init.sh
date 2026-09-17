#!/usr/bin/env bash
# SolrCloud initialisation for AKS, mirroring ADT 3.2.2 scripts/deploy:
#   zk          configure_zk_for_solr_cluster + configure_solr_collections
#               (chroot, urlScheme=https, security.json, upload configsets) - before Solr starts
#   collections create_solr_cluster_policy + create_solr_collections - once Solr is up
# Idempotent: existing chroot / collections are left alone; security.json and configsets
# are re-uploaded so a re-run picks up rotated credentials or a changed schema.
set -euo pipefail

: "${ZK_MEMBERS:?}"
SOLR_CLUSTER_ID="${SOLR_CLUSTER_ID:-is_cluster}"
ZK_HOST="${ZK_MEMBERS}/${SOLR_CLUSTER_ID}"
CONFIG_DIR=/opt/configuration/solr/generated_config
SECRETS=/etc/i2secrets
# collection[:configset type] - match_index1/2 share the match_index configset
COLLECTIONS="daod_index main_index chart_index highlight_index match_index1:match_index match_index2:match_index vq_index recordshare_index"

zk() {
  if solr zk ls "/${SOLR_CLUSTER_ID}" -z "${ZK_MEMBERS}" >/dev/null 2>&1; then
    echo "ZooKeeper chroot /${SOLR_CLUSTER_ID} exists"
  else
    solr zk mkroot "/${SOLR_CLUSTER_ID}" -z "${ZK_MEMBERS}"
  fi
  /opt/solr/server/scripts/cloud-scripts/zkcli.sh -zkhost "${ZK_HOST}" -cmd clusterprop -name urlScheme -val https
  solr zk cp "${SECRETS}/security.json" zk:/security.json -z "${ZK_HOST}"
  local c
  for c in ${COLLECTIONS}; do
    solr zk upconfig -z "${ZK_HOST}" -n "${c%%:*}" -d "${CONFIG_DIR}/${c#*:}"
  done
}

collections() {
  : "${SOLR_BASE_URL:?}" "${SOLR_ADMIN_DIGEST_USERNAME:?}" "${SOLR_ADMIN_DIGEST_PASSWORD:?}"
  local api="${SOLR_BASE_URL}/solr/admin/collections"
  local -a curl_args=( --silent --show-error -u "${SOLR_ADMIN_DIGEST_USERNAME}:${SOLR_ADMIN_DIGEST_PASSWORD}" --cacert "${SECRETS}/CA.cer" )

  # ADT pre-prod create_solr_cluster_policy: the affinity placement plugin puts each
  # replica of a shard on a different Solr node
  if curl --fail "${curl_args[@]}" "${SOLR_BASE_URL}/api/cluster/plugin" | grep -q '"\.placement-plugin"'; then
    echo "Placement plugin exists"
  else
    curl --fail "${curl_args[@]}" -X POST -H 'Content-Type: application/json' \
      -d '{"add":{"name":".placement-plugin","class":"org.apache.solr.cluster.placement.plugins.AffinityPlacementFactory"}}' \
      "${SOLR_BASE_URL}/api/cluster/plugin" >/dev/null
    echo "Added placement plugin (AffinityPlacementFactory)"
  fi

  local existing
  existing="$(curl --fail "${curl_args[@]}" "${api}?action=LIST&wt=json")"
  local c name response
  for c in ${COLLECTIONS}; do
    name="${c%%:*}"
    if grep -q "\"${name}\"" <<<"${existing}"; then
      echo "Collection ${name} exists"
      continue
    fi
    response="$(curl "${curl_args[@]}" "${api}?action=CREATE&name=${name}&collection.configName=${name}&numShards=${NUM_SHARDS:-1}&replicationFactor=${REPLICATION_FACTOR:-2}&wt=json")"
    if ! grep -Eq '"status" *: *0[,}]' <<<"${response}"; then
      echo "Failed to create collection ${name}: ${response}" >&2
      exit 1
    fi
    echo "Created collection ${name}"
  done
}

case "${1:-}" in
  zk) zk ;;
  collections) collections ;;
  *) echo "Usage: $0 {zk|collections}" >&2; exit 2 ;;
esac
