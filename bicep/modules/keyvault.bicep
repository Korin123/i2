// i2 Key Vault - the i2 secret set + PKI. RBAC auth, private endpoint,
// public access off unless test IPs are allow-listed.
import { getResourceName } from 'br/core:naming:latest'
param workload string
param environment string
param location string
param subnetId string
param privateDnsZoneVaultId string
param deployerObjectId string = ''
param allowedTestIps array = []
param tags object

var kvName = take(getResourceName('keyVault', workload, environment, '001'), 24)
var secretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    enabledForTemplateDeployment: true
    publicNetworkAccess: empty(allowedTestIps) ? 'Disabled' : 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: [for ip in allowedTestIps: { value: ip }]
    }
  }
}

resource secretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployerObjectId)) {
  name: guid(kv.id, deployerObjectId, secretsOfficerRoleId)
  scope: kv
  properties: {
    principalId: deployerObjectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsOfficerRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource pep 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: getResourceName('privateEndpoint', '${workload}-kv', environment, '001')
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [ { name: 'kv', properties: { privateLinkServiceId: kv.id, groupIds: [ 'vault' ] } } ]
  }
}

resource pepDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: pep
  name: 'default'
  properties: { privateDnsZoneConfigs: [ { name: 'vault', properties: { privateDnsZoneId: privateDnsZoneVaultId } } ] }
}

output vaultId string = kv.id
output vaultUri string = kv.properties.vaultUri
output vaultName string = kv.name
