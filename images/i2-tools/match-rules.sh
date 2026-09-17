#!/usr/bin/env bash
# Upload the system match rules and make them live, as ADT 3.2.2 does after Liberty starts
# (scripts/deploy update_match_rules; examples/pre-prod/deploy-pre-prod update_match_rules):
#   runAdminCommand.sh update_match_rules -> wait for the standby match index to be READY
#   -> runAdminCommand.sh switch_standby_match_index_to_live
# The wait polls /api/v1/admin/indexes/status as the ADT admin (basic auth), like ADT's
# wait_for_indexes_to_be_built, so it works with more than one Liberty pod.
set -euo pipefail
: "${FRONT_END_URI_INTERNAL:?}" "${ADT_ADMIN_USERNAME:?}"
ADT_ADMIN_PASSWORD="$(<"${ADT_ADMIN_PASSWORD_FILE:?}")"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-1800}"

index_status() {
  curl --silent --show-error --fail -u "${ADT_ADMIN_USERNAME}:${ADT_ADMIN_PASSWORD}" \
    --cacert "${SSL_CA_CERTIFICATE_FILE:?}" "${FRONT_END_URI_INTERNAL}/api/v1/admin/indexes/status"
}
ready_match_indexes() { # names of match indexes in state READY
  if command -v jq >/dev/null; then
    jq -r '.status.match[]? | select(.state == "READY") | .name'
  else
    tr -d '\n ' | grep -o '{[^{}]*"state":"READY"[^{}]*}' | grep -o '"name":"[^"]*"' | cut -d'"' -f4
  fi
}

echo ">>> Uploading system match rules"
/opt/i2-tools/scripts/runAdminCommand.sh update_match_rules

echo ">>> Waiting for the standby match index to be built"
waited=0
until status="$(index_status 2>/dev/null)" && [[ -n "$(ready_match_indexes <<<"${status}")" ]]; do
  if (( waited >= MAX_WAIT_SECONDS )); then
    echo "Standby match index not READY after ${MAX_WAIT_SECONDS}s. Last status: ${status:-<no response>}" >&2
    exit 1
  fi
  sleep 10; waited=$((waited + 10))
done
echo "READY: $(ready_match_indexes <<<"${status}" | tr '\n' ' ')"

echo ">>> Switching the standby match index to live"
/opt/i2-tools/scripts/runAdminCommand.sh switch_standby_match_index_to_live
echo ">>> System match rules are live"
