#!/usr/bin/env bash
# Deploy the Azure platform (Bicep) including the SQL Managed Instance. Bicep names and
# creates every resource; the deployment is named DEPLOYMENT_NAME so the other scripts can
# read the resource names back from its outputs (azure_outputs in 00-common.sh).
# The MI admin password is generated on the first run and stored in Key Vault as soon as the
# vault exists (before the MI finishes); later runs reuse it, so re-running does not rotate it.
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
       --parameters "$BICEP_PARAM" )
# read by the parameter file (readEnvironmentVariable), so the password is never on a command line
export SQL_MI_ADMIN_PASSWORD="$MI_ADMIN_PW"

# Once the SQL MI network exists, Azure owns the rules in its NSG and route table; declaring
# them again is rejected (ConflictWithNetworkIntentPolicy), so tell Bicep to leave them alone.
existing_mi_net="$(az resource list --subscription "$SUBSCRIPTION_ID" \
  --query "[?name=='rt-i2-sqlmi-${I2_ENV}-001' || name=='nsg-i2-sqlmi-${I2_ENV}-001'].id | [0]" -o tsv 2>/dev/null || true)"
if [[ -n "$existing_mi_net" ]]; then
  args+=( --parameters sqlMiNetworkExists=true )
  log "SQL MI network already exists: leaving its NSG and route table to Azure"
fi

# Public IPs for the Key Vault / ACR firewalls, kept out of the (possibly public) repo:
# ALLOWED_TEST_IPS="1.2.3.4 5.6.7.8" (env.sh or the pipeline variable group) overrides the file.
if [[ -n "${ALLOWED_TEST_IPS:-}" ]]; then
  ips="$(printf '"%s",' ${ALLOWED_TEST_IPS//,/ })"
  args+=( --parameters "allowedTestIps=[${ips%,}]" )
  log "Allowing test IPs through the Key Vault and ACR firewalls: ${ALLOWED_TEST_IPS}"
fi

# Azure DevOps agents inside the VNet (Managed DevOps Pool). Normally created once in the portal
# (it registers in Azure DevOps as the person creating it) and only used here by name
# (VNET_AGENT_POOL). CREATE_VNET_AGENT_POOL=true makes this deployment create it instead; the
# pipeline's identity then needs Administrator on agent pools in the Azure DevOps organisation.
# The organisation and project come from the pipeline run itself.
if [[ "${CREATE_VNET_AGENT_POOL:-false}" == true && -n "${VNET_AGENT_POOL:-}" ]]; then
  ADO_ORG_URL="${ADO_ORG_URL:-${SYSTEM_COLLECTIONURI:-}}"; ADO_ORG_URL="${ADO_ORG_URL%/}"
  ADO_PROJECT="${ADO_PROJECT:-${SYSTEM_TEAMPROJECT:-}}"
  [[ -n "$ADO_ORG_URL" && -n "$ADO_PROJECT" ]] || {
    echo "VNET_AGENT_POOL is set but the Azure DevOps organisation/project are unknown: run from the pipeline, or set ADO_ORG_URL and ADO_PROJECT" >&2; exit 1; }
  # Microsoft's DevOpsInfrastructure service principal (fixed app ID) joins the agents to the VNet
  DEVOPS_INFRA_SP_OBJECT_ID="${DEVOPS_INFRA_SP_OBJECT_ID:-$(az ad sp show --id 31687f79-5e43-4c1e-8c63-d9f4bff5cf8b --query id -o tsv 2>/dev/null || true)}"
  [[ -n "$DEVOPS_INFRA_SP_OBJECT_ID" ]] || {
    echo "Could not look up the DevOpsInfrastructure service principal. Set DEVOPS_INFRA_SP_OBJECT_ID in the variable group:" >&2
    echo "  az ad sp show --id 31687f79-5e43-4c1e-8c63-d9f4bff5cf8b --query id -o tsv" >&2; exit 1; }
  for rp in Microsoft.DevOpsInfrastructure Microsoft.DevCenter; do
    if [[ "$(az provider show --subscription "$SUBSCRIPTION_ID" -n "$rp" --query registrationState -o tsv 2>/dev/null)" != Registered ]]; then
      log "Registering resource provider $rp (one-time, a few minutes)"
      az provider register --subscription "$SUBSCRIPTION_ID" -n "$rp" --wait
    fi
  done
  args+=( --parameters devOpsPoolName="$VNET_AGENT_POOL" devOpsOrganizationUrl="$ADO_ORG_URL"
          devOpsProjectName="$ADO_PROJECT" devOpsInfrastructurePrincipalId="$DEVOPS_INFRA_SP_OBJECT_ID" )
  log "Managed DevOps Pool '$VNET_AGENT_POOL' for $ADO_ORG_URL, project '$ADO_PROJECT'"
fi

[[ -n "${AKS_ADMIN_GROUP_OBJECT_ID:-}" ]] || log "WARNING: AKS_ADMIN_GROUP_OBJECT_ID is not set: nobody gets AKS admin, Grafana admin or ACR push (unless set in $BICEP_PARAM)"

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

# Failed operations of a deployment, following nested module deployments down to the resource.
show_failures() {   # $1 = subscription deployment name
  az deployment sub show -n "$1" --query properties.error -o json 2>/dev/null || true
  local id rg name
  while read -r id; do
    [[ -z "$id" ]] && continue
    rg="$(cut -d/ -f5 <<<"$id")"; name="${id##*/}"
    echo "--- module $name (resource group $rg):"
    az deployment operation group list -g "$rg" -n "$name" \
      --query "[?properties.provisioningState=='Failed'].{resource:properties.targetResource.id, error:properties.statusMessage.error}" -o json 2>/dev/null || true
  done < <(az deployment operation sub list --name "$1" \
    --query "[?properties.provisioningState=='Failed' && properties.targetResource.resourceType=='Microsoft.Resources/deployments'].properties.targetResource.id" -o tsv 2>/dev/null)
  az deployment operation sub list --name "$1" \
    --query "[?properties.provisioningState=='Failed' && properties.targetResource.resourceType!='Microsoft.Resources/deployments'].{resource:properties.targetResource.id, error:properties.statusMessage.error}" -o json 2>/dev/null || true
}

store_password() {   # $1 = resource group, $2 = Key Vault
  # Written through the Azure Resource Manager API (control plane), not the Key Vault data
  # plane, so it works from an agent with no network path to the private Key Vault (e.g. a
  # Microsoft-hosted agent on the first deployment).
  # One secret; the db-init Job mounts it as SA_PASSWORD (k8s/secretproviderclass.yaml).
  # Key Vault secret names allow only letters, digits and hyphens.
  log "Storing MI admin password in Key Vault $2 (sqlmi-admin-password)"
  local body; body="$(printf '{"properties":{"value":"%s"}}' "$MI_ADMIN_PW")"
  az rest --method put --output none \
    --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/$1/providers/Microsoft.KeyVault/vaults/$2/secrets/sqlmi-admin-password?api-version=2023-07-01" \
    --body "$body"
}

log "Deploying bicep/main.bicep as '$DEPLOYMENT_NAME' (includes SQL MI - allow hours on first run)"
az deployment sub create --name "$DEPLOYMENT_NAME" "${args[@]}" --no-wait

if $new_pw; then
  # Store the password as soon as the Key Vault exists, not when the whole deployment ends:
  # the SQL MI takes hours, and a pipeline job timing out must not lose the password (the
  # deployment itself carries on in Azure).
  log "Waiting for the Key Vault module to finish, to store the MI admin password early"
  stored=false
  for _ in $(seq 1 120); do   # up to 60 min
    kv_dep="$(az deployment operation sub list --name "$DEPLOYMENT_NAME" \
      --query "[?properties.targetResource.resourceName=='i2-keyvault'].properties.targetResource.id | [0]" -o tsv 2>/dev/null || true)"
    if [[ -n "$kv_dep" ]]; then
      kv_rg="$(cut -d/ -f5 <<<"$kv_dep")"
      state="$(az deployment group show -g "$kv_rg" -n i2-keyvault --query properties.provisioningState -o tsv 2>/dev/null || true)"
      if [[ "$state" == Succeeded ]]; then
        store_password "$kv_rg" "$(az deployment group show -g "$kv_rg" -n i2-keyvault --query properties.outputs.vaultName.value -o tsv)"
        stored=true; break
      fi
      [[ "$state" == Failed ]] && break
    fi
    [[ "$(az deployment sub show -n "$DEPLOYMENT_NAME" --query properties.provisioningState -o tsv 2>/dev/null)" =~ ^(Failed|Canceled)$ ]] && break
    sleep 30
  done
  $stored || log "MI admin password not stored yet (Key Vault not ready or the deployment failed). The next successful run sets a new one and stores it."
fi

log "Waiting for the deployment to finish (SQL MI first creation takes hours). If this job times out,"
log "the deployment carries on in Azure: check it in the portal (Subscription > Deployments > $DEPLOYMENT_NAME)."
az deployment sub wait --name "$DEPLOYMENT_NAME" --custom "properties.provisioningState!='Running' && properties.provisioningState!='Accepted'" --interval 60 --timeout 43200 \
  || true   # returns an error when the deployment failed; the state is checked below
state="$(az deployment sub show -n "$DEPLOYMENT_NAME" --query properties.provisioningState -o tsv)"
if [[ "$state" != Succeeded ]]; then
  log "Deployment $DEPLOYMENT_NAME: $state. Errors:"
  show_failures "$DEPLOYMENT_NAME"
  exit 1
fi

azure_outputs
log "Infra deployed. Names the other scripts will use (from the deployment outputs):"
printf '    %-13s %s\n' RG "$RG" KV "$KV" ACR "$ACR" AKS "$AKS" WI_CLIENT_ID "$WI_CLIENT_ID" MI_FQDN "$MI_FQDN"
