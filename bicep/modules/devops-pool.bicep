// Managed DevOps Pool: Azure DevOps agents injected into the i2 VNet (snet-i2-agents), so the
// secrets, workload and sanity stages can reach the private Key Vault, ACR, AKS and SQL MI.
// Microsoft manages the VMs and the agent; the pool registers itself in Azure DevOps (no PAT).
// A Managed DevOps Pool needs a Dev Center project to belong to.
// Prereqs: Microsoft.DevOpsInfrastructure and Microsoft.DevCenter registered in the subscription
// (scripts/10-deploy-infra.sh does it), the DevOpsInfrastructure service principal able to join
// the subnet (network-devops-roles.bicep), and the deploying identity allowed to create agent
// pools in the Azure DevOps organisation.

param workload string
param environment string
param location string
@description('Agent pool name, in Azure and in Azure DevOps (VNET_AGENT_POOL in the variable group).')
param poolName string
@description('Azure DevOps organisation URL, e.g. https://dev.azure.com/<org> (System.CollectionUri).')
param organizationUrl string
@description('Azure DevOps project allowed to use the pool (System.TeamProject).')
param projectName string
param subnetId string
param vmSize string = 'Standard_D2ads_v5'
@description('Azure Pipelines image: has az, git, curl and jq.')
param image string = 'ubuntu-22.04/latest'
param maximumConcurrency int = 1
param tags object

resource devCenter 'Microsoft.DevCenter/devcenters@2024-02-01' = {
  name: 'dc-${workload}-${environment}-001'   // no naming key for Dev Center: named per the naming reference pattern
  location: location
  tags: tags
}

resource devCenterProject 'Microsoft.DevCenter/projects@2024-02-01' = {
  name: 'dcp-${workload}-${environment}-001'
  location: location
  tags: tags
  properties: { devCenterId: devCenter.id }
}

resource pool 'Microsoft.DevOpsInfrastructure/pools@2024-10-19' = {
  name: poolName
  location: location
  tags: tags
  properties: {
    devCenterProjectResourceId: devCenterProject.id
    maximumConcurrency: maximumConcurrency
    organizationProfile: {
      kind: 'AzureDevOps'
      organizations: [ { url: organizationUrl, projects: [ projectName ], parallelism: maximumConcurrency } ]
      // pool permissions in Azure DevOps follow the project's, not only the creator's
      permissionProfile: { kind: 'Inherit' }
    }
    agentProfile: { kind: 'Stateless' }   // a fresh agent per job, none kept when idle
    fabricProfile: {
      kind: 'Vmss'
      sku: { name: vmSize }
      images: [ { wellKnownImageName: image, buffer: '*' } ]
      networkProfile: { subnetId: subnetId }
      osProfile: { logonType: 'Service' }
      storageProfile: { osDiskStorageAccountType: 'Standard' }
    }
  }
}

output poolName string = pool.name
