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
  MI_ADMIN_PW="$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9'; echo)"
  MI_ADMIN_PW="Aa1@${MI_ADMIN_PW:0:28}"   # SQL complexity
  new_pw=true
fi

args=( --location "$LOCATION" --template-file bicep/main.bicep
       --parameters "$BICEP_PARAM" --parameters sqlMiAdminPassword="$MI_ADMIN_PW" )

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
  log "Storing MI admin password in Key Vault $KV (sqlmi-admin-password, SA_PASSWORD)"
  az keyvault secret set --vault-name "$KV" -n sqlmi-admin-password --value "$MI_ADMIN_PW" 1>/dev/null
  az keyvault secret set --vault-name "$KV" -n SA_PASSWORD          --value "$MI_ADMIN_PW" 1>/dev/null
fi
log "Infra deployed. Names the other scripts will use (from the deployment outputs):"
printf '    %-13s %s\n' RG "$RG" KV "$KV" ACR "$ACR" AKS "$AKS" WI_CLIENT_ID "$WI_CLIENT_ID" MI_FQDN "$MI_FQDN"
