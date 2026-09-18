// Lets Microsoft's DevOpsInfrastructure service principal place Managed DevOps Pool agents in the
// VNet (Reader + Network Contributor on the VNet, as its documentation requires).
// Deployed into the VNet's resource group.
param vnetName string
@description('Object ID of the DevOpsInfrastructure service principal in this tenant.')
param principalId string

var roles = {
  reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  networkContributor: '4d97b98b-1d4f-4787-a291-c67834d212e7'
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in items(roles): {
  name: guid(vnet.id, principalId, role.value)
  // Region policies that deny resources without a location allow 'global'
  #disable-next-line BCP187
  location: 'global'
  scope: vnet
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.value)
  }
}]
