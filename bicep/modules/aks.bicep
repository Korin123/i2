// Private AKS cluster. Zone-redundant system + memory-weighted user pool for
// the i2 stateful workloads (Solr/ZooKeeper). Azure CNI overlay (Cilium),
// Entra + Azure RBAC, workload identity, KV secrets provider, private API.
import { getResourceName } from 'br/core:naming:latest'
param workload string
param environment string
param location string
param nodeSubnetId string
param adminGroupObjectId string
param deployerObjectId string = ''
param logAnalyticsWorkspaceId string
param acrId string
@allowed([ 'loadBalancer', 'userDefinedRouting' ])
param outboundType string = 'loadBalancer'
param tags object

var aksName = getResourceName('aksCluster', workload, environment, '001')
var hasAdminGroup = !empty(adminGroupObjectId) && adminGroupObjectId != '00000000-0000-0000-0000-000000000000'

resource aks 'Microsoft.ContainerService/managedClusters@2024-09-01' = {
  name: aksName
  location: location
  tags: tags
  sku: { name: 'Base', tier: 'Standard' }
  identity: { type: 'SystemAssigned' }
  properties: {
    dnsPrefix: aksName
    enableRBAC: true
    disableLocalAccounts: true
    aadProfile: { managed: true, enableAzureRBAC: true, adminGroupObjectIDs: hasAdminGroup ? [ adminGroupObjectId ] : [] }
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkDataplane: 'cilium'
      networkPolicy: 'cilium'
      loadBalancerSku: 'standard'
      outboundType: outboundType
    }
    apiServerAccessProfile: { enablePrivateCluster: true }
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: 3
        vmSize: 'Standard_D4s_v5'
        vnetSubnetID: nodeSubnetId
        availabilityZones: [ '1', '2', '3' ]
        osDiskType: 'Managed'
        nodeTaints: [ 'CriticalAddonsOnly=true:NoSchedule' ]
        type: 'VirtualMachineScaleSets'
      }
      {
        name: 'i2stateful'
        mode: 'User'
        count: 3
        vmSize: 'Standard_E8s_v5'
        vnetSubnetID: nodeSubnetId
        availabilityZones: [ '1', '2', '3' ]
        osDiskType: 'Managed'
        type: 'VirtualMachineScaleSets'
        nodeLabels: { workload: 'i2-analyze' }
      }
    ]
    addonProfiles: {
      omsagent: { enabled: true, config: { logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId } }
      azureKeyvaultSecretsProvider: { enabled: true, config: { enableSecretRotation: 'true' } }
    }
    azureMonitorProfile: { metrics: { enabled: true, kubeStateMetrics: {} } }
    oidcIssuerProfile: { enabled: true }
    securityProfile: { workloadIdentity: { enabled: true } }
  }
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, acrId, 'acrpull')
  scope: resourceGroup()
  properties: {
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalType: 'ServicePrincipal'
  }
}

resource deployerClusterAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerObjectId)) {
  name: guid(aks.id, deployerObjectId, 'aks-rbac-cluster-admin')
  scope: aks
  properties: {
    principalId: deployerObjectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')
    principalType: 'ServicePrincipal'
  }
}

output clusterName string = aks.name
output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL
