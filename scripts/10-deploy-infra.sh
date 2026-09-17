#!/usr/bin/env bash
# Deploy the Azure platform (Bicep) including the SQL Managed Instance. Bicep names and
# creates every resource; the deployment is named DEPLOYMENT_NAME so the other scripts can
# read the resource names back from its outputs (azure_outputs in 00-common.sh).
# The MI admin password is generated on the first run and stored in Key Vault after the
# vault exists; later runs reuse it, so re-running to apply a fix does not rotate it.
# MI first creation takes hours.
#   WHAT_IF=true scripts/10-deploy-infra.sh    preview the changes (az deployment what-if), deploy nothing
source "$(dirname "$0")/00-common.sh"
: "${SUBSCRIPTION_ID:?}"; : "${LOCATION:?}"; : "${BICEP_PARAM:?}"

az account set --subscription "$SUBSCRIPTION_ID"
az bicep restore --file bicep/main.bicep

# Key Vault from a previous deployment, if there is one
kv="${KV:-$(az deployment sub show -n "$DEPLOYMENT_NAME" --query properties.outputs.keyVaultName.value -o tsv 2>/dev/null || true)}"
if [[ -n "$kv" ]] && MI_ADMIN_PW="$(az keyvault secret show --vault-name "$kv" -n sqlmi-admin-password --query value -o tsv 2>/dev/null)" \
   && [[ -n "$MI_ADMIN_PW" ]]; then
  log "Reusing the MI admin password from Key Vault $kv"
  new_pw=false
else
  [[ -n "$kv" ]] && log "Key Vault $kv not readable from here (private network): generating a new MI admin password, applied to the MI and stored in Key Vault by this run"
  MI_ADMIN_PW="$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9'; echo)"
  MI_ADMIN_PW="Aa1@${MI_ADMIN_PW:0:28}"   # SQL complexity
  new_pw=true
fi

args=( --location "$LOCATION" --template-file bicep/main.bicep
       --parameters "$BICEP_PARAM" --parameters sqlMiAdminPassword="$MI_ADMIN_PW" )

# Public IPs for the Key Vault / ACR firewalls, kept out of the (possibly public) repo:
# ALLOWED_TEST_IPS="1.2.3.4 5.6.7.8" (env.sh or the pipeline variable group) overrides the file.
if [[ -n "${ALLOWED_TEST_IPS:-}" ]]; then
  ips="$(printf '"%s",' ${ALLOWED_TEST_IPS//,/ })"
  args+=( --parameters "allowedTestIps=[${ips%,}]" )
  log "Allowing test IPs through the Key Vault and ACR firewalls: ${ALLOWED_TEST_IPS}"
fi

# The identity running the deployment needs Key Vault and AKS access for the later steps.
# In the pipeline (AzureCLI task with addSpnToEnvironment) look up the service principal's
# object ID; otherwise DEPLOYER_OBJECT_ID or the value in the parameter file is used.
if [[ -z "${DEPLOYER_OBJECT_ID:-}" && -n "${servicePrincipalId:-}" ]]; then
  DEPLOYER_OBJECT_ID="$(az ad sp show --id "$servicePrincipalId" --query id -o tsv 2>/dev/null || true)"
  [[ -n "$DEPLOYER_OBJECT_ID" ]] || log "WARNING: could not read the service principal's object ID; set deployerObjectId in $BICEP_PARAM"
fi
[[ -n "${DEPLOYER_OBJECT_ID:-}" ]] && args+=( --parameters deployerObjectId="$DEPLOYER_OBJECT_ID" )

WHAT_IF="${WHAT_IF:-false}"
if [[ "${WHAT_IF,,}" == true ]]; then
  log "What-if for bicep/main.bicep (no changes are made)"
  az deployment sub what-if "${args[@]}"
  exit 0
fi

log "Deploying bicep/main.bicep as '$DEPLOYMENT_NAME' (includes SQL MI - allow hours on first run)"
az deployment sub create --name "$DEPLOYMENT_NAME" "${args[@]}" >/dev/null

azure_outputs
if $new_pw; then
  # Written through the Azure Resource Manager API (control plane), not the Key Vault data
  # plane, so it works from an agent with no network path to the private Key Vault (e.g. a
  # Microsoft-hosted agent on the first deployment). A new password is only generated when the
  # stored one cannot be read, and it is applied to the MI by this same deployment, so the MI
  # and Key Vault always agree.
  log "Storing MI admin password in Key Vault $KV (sqlmi-admin-password, SA_PASSWORD)"
  body="$(printf '{"properties":{"value":"%s"}}' "$MI_ADMIN_PW")"
  for secret in sqlmi-admin-password SA_PASSWORD; do
    az rest --method put --output none \
      --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG}/providers/Microsoft.KeyVault/vaults/${KV}/secrets/${secret}?api-version=2023-07-01" \
      --body "$body"
  done
fi
log "Infra deployed. Names the other scripts will use (from the deployment outputs):"
printf '    %-13s %s\n' RG "$RG" KV "$KV" ACR "$ACR" AKS "$AKS" WI_CLIENT_ID "$WI_CLIENT_ID" MI_FQDN "$MI_FQDN"
