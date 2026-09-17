// =====================================================================
// i2 Analyze on Azure - platform infrastructure (subscription scope).
// Deploys network, monitoring, Key Vault, ACR, storage, AKS, workload
// identity, and the SQL Managed Instance data tier, into one resource
// group named by the naming functions in bicep/naming.
// networkMode 'new' creates the VNet, subnets and private DNS zones;
// 'existing' attaches i2's subnets to an existing VNet and uses existing
// private DNS zones.
// =====================================================================

targetScope = 'subscription'

import { getResourceName } from 'naming/naming.bicep'

@description('Workload short name used in resource names.')
param workload string = 'i2'

@description('Environment code used in resource names, e.g. dev, test, prod.')
param environment string

@description('Primary region (three zones for the HA node pools).')
param location string

@description('new = create a VNet and private DNS zones for i2. existing = attach to an existing VNet and private DNS zones.')
@allowed([ 'new', 'existing' ])
param networkMode string = 'new'

@description('The /24 for i2: the new VNet\'s address space, or (existing mode) a range already added to the existing VNet. Subnet CIDRs derive from it.')
param i2AddressPrefix string = '10.200.212.0/24'

@description('existing mode: name of the VNet the i2 subnets attach to.')
param existingVnetName string = ''

@description('existing mode: resource group of that VNet.')
param existingVnetResourceGroupName string = ''

@description('existing mode: resource group holding the private DNS zones (privatelink.vaultcore.azure.net, privatelink.azurecr.io, privatelink.blob.core.windows.net) linked to the VNet.')
param privateDnsResourceGroupName string = existingVnetResourceGroupName

@description('Object ID of the AKS admin Entra group (cluster-admin binding). Zeros placeholder is skipped.')
param aksAdminGroupObjectId string = '00000000-0000-0000-0000-000000000000'

@description('AKS egress model.')
@allowed([ 'loadBalancer', 'userDefinedRouting' ])
param aksOutboundType string = 'loadBalancer'

@description('Object ID of the pipeline deployer SPN. Granted KV Secrets Officer + AKS RBAC Cluster Admin. Supply via pipeline; empty skips the role bindings.')
param deployerObjectId string = ''

@description('Public IPs allow-listed on KV/ACR for testing. Empty = private-endpoint-only.')
param allowedTestIps array = []

// --- SQL Managed Instance (data tier) ---
@description('MI SQL administrator login.')
param sqlMiAdminLogin string = 'i2miadmin'

@secure()
@description('MI SQL administrator password. Supply from Key Vault via the pipeline - never hard-coded.')
param sqlMiAdminPassword string

@description('MI instance collation. IMMUTABLE at creation - set it to Collation in the i2 config\'s InfoStoreNamesSQLServer.properties (scripts/30-build-images.sh build prints it).')
param sqlMiCollation string = 'Latin1_General_100_CI_AS'

@description('MI vCores (GP Gen5 4-80).')
param sqlMiVCores int = 8

@description('Optional Entra admin group object ID for MI management-plane admin.')
param sqlMiEntraAdminGroupObjectId string = ''

@description('Tags applied to every resource. Add owner, cost centre etc. in the parameter file.')
param tags object = {
  workload: 'i2-analyze'
  environment: environment
}

var rgName = getResourceName('resourceGroup', workload, environment, '001')

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
  tags: tags
}

var newNetwork = networkMode == 'new'

module net 'modules/network-nsgs.bicep' = {
  name: 'i2-net-nsgs'
  scope: rg
  params: { workload: workload, environment: environment, location: location, tags: tags }
}

// new: a VNet with the i2 subnets, in the i2 resource group
module vnet 'modules/network-vnet.bicep' = if (newNetwork) {
  name: 'i2-net-vnet'
  scope: rg
  params: {
    workload: workload, environment: environment, location: location
    addressPrefix: i2AddressPrefix
    aksNsgId: net.outputs.aksNsgId
    sqlMiNsgId: net.outputs.sqlMiNsgId
    sqlMiRouteTableId: net.outputs.sqlMiRouteTableId
    tags: tags
  }
}

// existing: add the i2 subnets to an existing VNet
module subnets 'modules/network-subnets.bicep' = if (!newNetwork) {
  name: 'i2-net-subnets'
  scope: resourceGroup(subscription().subscriptionId, newNetwork ? rgName : existingVnetResourceGroupName)
  params: {
    existingVnetName: existingVnetName
    i2AddressPrefix: i2AddressPrefix
    aksNsgId: net.outputs.aksNsgId
    sqlMiNsgId: net.outputs.sqlMiNsgId
    sqlMiRouteTableId: net.outputs.sqlMiRouteTableId
  }
}

// new: private DNS zones linked to the new VNet
module dns 'modules/private-dns.bicep' = if (newNetwork) {
  name: 'i2-net-dns'
  scope: rg
  params: { vnetId: vnet!.outputs.vnetId, tags: tags }
}

var aksSubnetId = newNetwork ? vnet!.outputs.aksSubnetId : subnets!.outputs.aksSubnetId
var pepSubnetId = newNetwork ? vnet!.outputs.pepSubnetId : subnets!.outputs.pepSubnetId
var sqlMiSubnetId = newNetwork ? vnet!.outputs.sqlMiSubnetId : subnets!.outputs.sqlMiSubnetId

// existing: central zones already linked to the VNet.
// 4-arg resourceId (at subscription scope a 3-arg first value is read as a sub ID).
var existingDnsRg = empty(privateDnsResourceGroupName) ? 'unused' : privateDnsResourceGroupName
var dnsZoneVaultId = newNetwork ? dns!.outputs.vaultZoneId : resourceId(subscription().subscriptionId, existingDnsRg, 'Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')
var dnsZoneAcrId = newNetwork ? dns!.outputs.acrZoneId : resourceId(subscription().subscriptionId, existingDnsRg, 'Microsoft.Network/privateDnsZones', 'privatelink.azurecr.io')
#disable-next-line no-hardcoded-env-urls
var dnsZoneBlobId = newNetwork ? dns!.outputs.blobZoneId : resourceId(subscription().subscriptionId, existingDnsRg, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.core.windows.net')

module monitoring 'modules/monitoring.bicep' = {
  name: 'i2-monitoring'
  scope: rg
  params: { workload: workload, environment: environment, location: location, grafanaAdminGroupObjectId: aksAdminGroupObjectId, tags: tags }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'i2-keyvault'
  scope: rg
  params: {
    workload: workload, environment: environment, location: location
    subnetId: pepSubnetId
    privateDnsZoneVaultId: dnsZoneVaultId
    deployerObjectId: deployerObjectId
    allowedTestIps: allowedTestIps
    tags: tags
  }
}

module acr 'modules/acr.bicep' = {
  name: 'i2-acr'
  scope: rg
  params: {
    workload: workload, environment: environment, location: location
    subnetId: pepSubnetId
    privateDnsZoneAcrId: dnsZoneAcrId
    allowedTestIps: allowedTestIps
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'i2-storage'
  scope: rg
  params: {
    workload: workload, environment: environment, location: location
    subnetId: pepSubnetId
    privateDnsZoneBlobId: dnsZoneBlobId
    readerObjectId: deployerObjectId
    tags: tags
  }
}

module aks 'modules/aks.bicep' = {
  name: 'i2-aks'
  scope: rg
  params: {
    workload: workload, environment: environment, location: location
    nodeSubnetId: aksSubnetId
    adminGroupObjectId: aksAdminGroupObjectId
    deployerObjectId: deployerObjectId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    acrId: acr.outputs.acrId
    outboundType: aksOutboundType
    tags: tags
  }
}

module workloadIdentity 'modules/workload-identity.bicep' = {
  name: 'i2-workload-identity'
  scope: rg
  params: {
    workload: workload, environment: environment, location: location
    oidcIssuerUrl: aks.outputs.oidcIssuerUrl
    keyVaultId: keyVault.outputs.vaultId
    tags: tags
  }
}

module sqlMi 'modules/sql-mi.bicep' = {
  name: 'i2-sqlmi'
  scope: rg
  params: {
    workload: workload, environment: environment, location: location
    subnetId: sqlMiSubnetId
    adminLogin: sqlMiAdminLogin
    adminPassword: sqlMiAdminPassword
    collation: sqlMiCollation
    vCores: sqlMiVCores
    entraAdminGroupObjectId: sqlMiEntraAdminGroupObjectId
    tags: tags
  }
}

// Read by scripts/00-common.sh (azure_outputs), so resource names never need typing by hand
output resourceGroupName string = rg.name
output acrName string = acr.outputs.acrName
output aksClusterName string = aks.outputs.clusterName
output acrLoginServer string = acr.outputs.loginServer
output keyVaultName string = keyVault.outputs.vaultName
output storageAccountName string = storage.outputs.storageAccountName
output workloadIdentityClientId string = workloadIdentity.outputs.clientId
output sqlManagedInstanceFqdn string = sqlMi.outputs.managedInstanceFqdn
@description('Where to place self-hosted Azure DevOps agent VMs (they need network access to the private Key Vault, ACR and AKS).')
output agentsSubnetId string = newNetwork ? vnet!.outputs.agentsSubnetId : subnets!.outputs.agentsSubnetId
