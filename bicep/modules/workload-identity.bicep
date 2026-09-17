// UAMI federated to the i2 pod service accounts, granted Key Vault Secrets
// User so the KV CSI driver can project the i2 secret set into the pods.
import { getResourceName } from '../naming/naming.bicep'
param workload string
param environment string
param location string
param oidcIssuerUrl string
param keyVaultId string
param namespace string = 'i2analyze'
param serviceAccounts array = [ 'i2-liberty', 'i2-solr', 'i2-zookeeper', 'i2-connectors', 'i2-bootstrap' ]
param tags object

var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: getResourceName('managedIdentityUserAssigned', workload, environment, '001')
  location: location
  tags: tags
}

@batchSize(1)
resource fedCreds 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = [
  for sa in serviceAccounts: {
    parent: uami
    name: 'fed-${sa}'
    properties: {
      issuer: oidcIssuerUrl
      subject: 'system:serviceaccount:${namespace}:${sa}'
      audiences: [ 'api://AzureADTokenExchange' ]
    }
  }
]

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = { name: last(split(keyVaultId, '/')) }

resource secretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultId, uami.id, secretsUserRoleId)
  // Region policies that deny resources without a location allow 'global'
  #disable-next-line BCP187
  location: 'global'
  scope: kv
  properties: {
    principalId: uami.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

output clientId string = uami.properties.clientId
output principalId string = uami.properties.principalId
