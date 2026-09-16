#!/usr/bin/env bash
# Deploy the Azure platform (Bicep) including the SQL Managed Instance.
# Generates the MI admin password, passes it as a secure parameter, and writes
# it to Key Vault after the vault exists. MI first creation takes hours.
source "$(dirname "$0")/00-common.sh"
: "${SUBSCRIPTION_ID:?}"; : "${BICEP_PARAM:?}"

az account set --subscription "$SUBSCRIPTION_ID"
az bicep restore --file bicep/main.bicep

MI_ADMIN_PW="$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9'; echo)"
MI_ADMIN_PW="Aa1@${MI_ADMIN_PW:0:28}"   # SQL complexity

log "Deploying bicep/main.bicep (this includes SQL MI - allow hours on first run)"
az deployment sub create \
  --name "i2-infra-$(date +%s)" \
  --location "$LOCATION" \
  --template-file bicep/main.bicep \
  --parameters "$BICEP_PARAM" \
  --parameters sqlMiAdminPassword="$MI_ADMIN_PW"

log "Storing MI admin password in Key Vault (sqlmi-admin-password, SA_PASSWORD)"
az keyvault secret set --vault-name "$KV" -n sqlmi-admin-password --value "$MI_ADMIN_PW" 1>/dev/null
az keyvault secret set --vault-name "$KV" -n SA_PASSWORD          --value "$MI_ADMIN_PW" 1>/dev/null
log "Infra deployed. Capture the outputs (workloadIdentityClientId, sqlManagedInstanceFqdn) into env.sh."
