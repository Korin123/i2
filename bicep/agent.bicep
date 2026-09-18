// Self-hosted Azure DevOps agent VM in the i2 VNet (snet-i2-agents). The secrets, workload and
// sanity stages run on it, because Key Vault, ACR and AKS are private. Same pattern as a plain
// self-hosted agent: Ubuntu VM, a custom script installs the agent and registers it with a PAT.
// Deployed into the i2 resource group by scripts/15-deploy-agent.sh.
targetScope = 'resourceGroup'

param environment string
param location string = resourceGroup().location
param subnetId string
param vmSize string = 'Standard_D2s_v5'
param adminUsername string = 'azureuser'
@description('SSH public key. No inbound access exists; the script generates a throwaway key.')
param adminSshPublicKey string
@description('Azure DevOps organisation URL, e.g. https://dev.azure.com/<org>')
param adoOrganizationUrl string
@description('Agent pool (created in Azure DevOps beforehand)')
param adoAgentPool string
@secure()
@description('PAT with Agent Pools (read, manage), used once to register the agent')
param adoPat string
@description('Changes on every deploy (scripts/15), so the install script re-runs; it is safe to repeat')
param forceUpdateTag string = ''
param agentVersion string = '4.248.0'
param tags object = {}

var name = 'vm-i2-agent-${environment}-001'

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-${name}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [ { name: 'ipconfig1', properties: { subnet: { id: subnetId }, privateIPAllocationMethod: 'Dynamic' } } ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    hardwareProfile: { vmSize: vmSize }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-jammy', sku: '22_04-lts-gen2', version: 'latest' }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' }, deleteOption: 'Delete' }
    }
    osProfile: {
      computerName: name
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: { publicKeys: [ { path: '/home/${adminUsername}/.ssh/authorized_keys', keyData: adminSshPublicKey } ] }
      }
    }
    networkProfile: { networkInterfaces: [ { id: nic.id, properties: { deleteOption: 'Delete' } } ] }
  }
}

// Installs the tools the pipeline stages use (az, jq, git, curl, unzip; the scripts add kubectl
// and kubelogin), then the agent as a service. The PAT line runs without trace output.
var script = '''#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
# first boot: wait for cloud-init's own apt run, or both write the package lists at once
cloud-init status --wait >/dev/null 2>&1 || true
for i in 1 2 3 4 5; do
  rm -rf /var/lib/apt/lists/partial/*
  apt-get -o DPkg::Lock::Timeout=300 update && break
  echo "apt-get update failed (attempt $i), retrying"; rm -rf /var/lib/apt/lists/*; sleep 20
done
apt-get -o DPkg::Lock::Timeout=300 install -y curl jq git unzip libicu-dev ca-certificates
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
AGENT_DIR=/home/{0}/agent
sudo -u {0} mkdir -p "$AGENT_DIR" && cd "$AGENT_DIR"
sudo -u {0} curl -fsSL -o agent.tgz https://download.agent.dev.azure.com/agent/{1}/vsts-agent-linux-x64-{1}.tar.gz
sudo -u {0} tar -xzf agent.tgz
sudo -u {0} ./config.sh --unattended --url "{2}" --auth pat --token "{3}" --pool "{4}" --agent "{5}" --replace --acceptTeeEula >/dev/null
./svc.sh install {0} || true
./svc.sh start
echo "agent {5} registered in pool {4}"
'''

resource install 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'install-ado-agent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    forceUpdateTag: forceUpdateTag
    protectedSettings: {
      script: base64(format(script, adminUsername, agentVersion, adoOrganizationUrl, adoPat, adoAgentPool, name))
    }
  }
}

output vmName string = vm.name
