#!/usr/bin/env bash
# Deploy the self-hosted Azure DevOps agent VM into the i2 VNet (bicep/agent.bicep), so the
# secrets, workload and sanity stages can reach the private Key Vault, ACR and AKS.
# Needs, from the variable group: VNET_AGENT_POOL (pool created in Azure DevOps beforehand) and
# ADO_AGENT_PAT (secret; PAT with Agent Pools read + manage). The organisation comes from the run.
source "$(dirname "$0")/00-common.sh"
: "${VNET_AGENT_POOL:?set VNET_AGENT_POOL in the variable group}"
: "${ADO_AGENT_PAT:?set ADO_AGENT_PAT (secret) in the variable group}"
ADO_ORG_URL="${ADO_ORG_URL:-${SYSTEM_COLLECTIONURI:-}}"; ADO_ORG_URL="${ADO_ORG_URL%/}"
: "${ADO_ORG_URL:?run from the pipeline, or set ADO_ORG_URL}"

azure_outputs
subnet="$(az deployment sub show -n "$DEPLOYMENT_NAME" --query properties.outputs.agentsSubnetId.value -o tsv)"

# No inbound access exists to the VM; Azure requires a key, so use a throwaway one. An existing
# VM keeps the key it has (Azure does not allow changing it).
vm="vm-i2-agent-${I2_ENV}-001"
pubkey="$(az vm show -g "$RG" -n "$vm" --query "osProfile.linuxConfiguration.ssh.publicKeys[0].keyData" -o tsv 2>/dev/null || true)"
if [[ -z "$pubkey" ]]; then
  key="$(mktemp -u)"; ssh-keygen -q -t ed25519 -N "" -f "$key"
  pubkey="$(cat "$key.pub")"; rm -f "$key" "$key.pub"
fi

log "Deploying agent VM $vm into $RG (pool $VNET_AGENT_POOL)"
az deployment group create -g "$RG" -n i2-agent --template-file bicep/agent.bicep \
  --parameters environment="$I2_ENV" subnetId="$subnet" adminSshPublicKey="$pubkey" \
               adoOrganizationUrl="$ADO_ORG_URL" adoAgentPool="$VNET_AGENT_POOL" \
               adoPat="$ADO_AGENT_PAT" forceUpdateTag="$(date +%s)" -o none
log "Agent deployed. It shows Online in pool $VNET_AGENT_POOL within a few minutes."
