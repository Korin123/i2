// Private storage for the i2 distribution and shared config. No public access,
// private blob endpoint. The team uploads the distribution once from on-network.
import { getResourceName } from '../naming/naming.bicep'
param workload string
param environment string
param location string
param subnetId string
param privateDnsZoneBlobId string
param readerObjectId string = ''
@description('Appended to names that must be unique across Azure.')
param nameSuffix string = ''
param tags object

var saName = take(replace(getResourceName('storageAccount', '${workload}dist', environment, '001${nameSuffix}'), '-', ''), 24)
var blobDataReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'

resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  #disable-next-line BCP334
  name: saName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
    networkAcls: { defaultAction: 'Deny', bypass: 'AzureServices' }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = { parent: sa, name: 'default' }
resource distContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = { parent: blobService, name: 'i2-distribution' }

resource pep 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: getResourceName('privateEndpoint', '${workload}-dist', environment, '001')
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [ { name: 'blob', properties: { privateLinkServiceId: sa.id, groupIds: [ 'blob' ] } } ]
  }
}
resource pepDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: pep
  name: 'default'
  properties: { privateDnsZoneConfigs: [ { name: 'blob', properties: { privateDnsZoneId: privateDnsZoneBlobId } } ] }
}

resource blobReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(readerObjectId)) {
  name: guid(sa.id, readerObjectId, blobDataReaderRoleId)
  // Region policies that deny resources without a location allow 'global'
  #disable-next-line BCP187
  location: 'global'
  scope: sa
  properties: {
    principalId: readerObjectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobDataReaderRoleId)
    principalType: 'ServicePrincipal'
  }
}

output storageAccountName string = sa.name
