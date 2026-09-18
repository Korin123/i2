#!/usr/bin/env bash
# Destroy an environment: deletes its resource group (everything Bicep created, including the
# VNet, AKS, SQL MI and the agent VM), purges the soft-deleted Key Vault so the same names
# can be deployed again, and removes the subscription deployment record.
# Asks you to type the environment name first; CONFIRM=<env> skips the question.
# Deleting a SQL Managed Instance can take an hour or more.
source "$(dirname "$0")/00-common.sh"
: "${SUBSCRIPTION_ID:?SUBSCRIPTION_ID is not set}"

outputs() { azs deployment sub show -n "$DEPLOYMENT_NAME" --query "properties.outputs.$1.value" -o tsv 2>/dev/null || true; }
rg="${RG:-$(outputs resourceGroupName)}"; rg="${rg:-rg-i2-${I2_ENV}-001}"
kv="${KV:-$(outputs keyVaultName)}"
# No deployment record (e.g. the deployment failed): find the vault in the group, or among deleted vaults
[[ -n "$kv" ]] || kv="$(azs keyvault list -g "$rg" --query "[0].name" -o tsv 2>/dev/null || true)"
[[ -n "$kv" ]] || kv="$(azs keyvault list-deleted --query "[?starts_with(name, 'kv-i2-${I2_ENV}-')].name | [0]" -o tsv 2>/dev/null || true)"

echo "Subscription: $(azs account show --query name -o tsv)"
echo "This DELETES resource group '$rg' and everything in it (environment '$I2_ENV'),"
echo "then purges Key Vault '$kv'. It cannot be undone."
if [[ "${CONFIRM:-}" != "$I2_ENV" ]]; then
  read -rp "Type the environment name ($I2_ENV) to confirm: " answer
  [[ "$answer" == "$I2_ENV" ]] || { echo "Not confirmed - nothing deleted."; exit 1; }
fi

if [[ "$(azs group exists -n "$rg")" == true ]]; then
  log "Deleting resource group $rg (SQL MI deletion can take an hour or more)"
  azs group delete -n "$rg" --yes
else
  log "Resource group $rg does not exist"
fi

if azs keyvault show-deleted -n "$kv" >/dev/null 2>&1; then
  log "Purging deleted Key Vault $kv"
  azs keyvault purge -n "$kv" || \
    log "WARNING: could not purge $kv (purge protection on?). The name stays reserved for 90 days: redeploy with a different instance or wait."
fi

azs deployment sub delete -n "$DEPLOYMENT_NAME" >/dev/null 2>&1 || true
log "Environment '$I2_ENV' destroyed. In Azure DevOps, remove the offline agent from the agent pool."
log "To recreate it: run the pipeline with Infra ticked (runbook step 5), then the agent VM (step 6) and secrets (step 7)."
