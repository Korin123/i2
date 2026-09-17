// Premium private ACR. AKS pulls over the private endpoint; the local ADT
// build pushes the configured Liberty image and the base images here.
import { getResourceName } from '../naming/naming.bicep'
param workload string
param environment string
param location string
param subnetId string
param privateDnsZoneAcrId string
param allowedTestIps array = []
@description('Entra group allowed to push images (people running scripts/30-build-images.sh push). Empty or zeros = skipped.')
param pushGroupObjectId string = ''
param tags object

var acrPushRoleId = '8311e382-0749-4cb8-b61a-304f252e45ec'
var hasPushGroup = !empty(pushGroupObjectId) && pushGroupObjectId != '00000000-0000-0000-0000-000000000000'

var acrName = take(replace(getResourceName('containerRegistry', workload, environment, '001'), '-', ''), 50)
var acrIpRules = [for ip in allowedTestIps: { action: 'Allow', value: ip }]

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  #disable-next-line BCP334
  name: acrName
  location: location
  tags: tags
  sku: { name: 'Premium' }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: empty(allowedTestIps) ? 'Disabled' : 'Enabled'
    networkRuleSet: empty(allowedTestIps) ? null : { defaultAction: 'Deny', ipRules: acrIpRules }
    networkRuleBypassOptions: 'AzureServices'
  }
}

resource pep 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: getResourceName('privateEndpoint', '${workload}-acr', environment, '001')
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [ { name: 'acr', properties: { privateLinkServiceId: acr.id, groupIds: [ 'registry' ] } } ]
  }
}

resource pepDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: pep
  name: 'default'
  properties: { privateDnsZoneConfigs: [ { name: 'acr', properties: { privateDnsZoneId: privateDnsZoneAcrId } } ] }
}

resource push 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (hasPushGroup) {
  name: guid(acr.id, pushGroupObjectId, acrPushRoleId)
  scope: acr
  properties: {
    principalId: pushGroupObjectId
    principalType: 'Group'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPushRoleId)
  }
}

output acrId string = acr.id
output loginServer string = acr.properties.loginServer
output acrName string = acr.name
