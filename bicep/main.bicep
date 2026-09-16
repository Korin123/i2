// =====================================================================
// i2 Analyze on Azure - platform infrastructure (subscription scope).
// Deploys network, monitoring, Key Vault, ACR, storage, AKS, workload
// identity, and the SQL Managed Instance data tier, into one resource
// group. The VNet is EXISTING (brownfield) - i2 only adds its subnets.
// Author: Korin Taunton, Lead Architect.
// =====================================================================

targetScope = 'subscription'

import { getResourceName } from 'br/core:naming:latest'

@description('Workload short name for the naming module.')
param workload string = 'i2'

@description('Environment code.')
param environment string = 'alpha'

@description('Primary region (three zones for the HA node pools).')
param location string = 'uksouth'

@description('The /24 added to the existing VNet, solely for i2. Derives the subnet CIDRs. PREREQUISITE: added to the VNet address space by the VNet owner.')
param i2AddressPrefix string = '10.200.212.0/24'

@description('Name of the existing (brownfield) VNet the i2 subnets attach to.')
param existingVnetName string

@description('Resource group of the existing VNet.')
param existingVnetResourceGroupName string

@description('Resource group holding the central private DNS zones already linked to the VNet.')
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

@description('MI instance collation. IMMUTABLE at creation - confirm against i2 4.4.x Information Store prerequisites.')
param sqlMiCollation string = 'Latin1_General_100_CI_AS'

@description('MI vCores (GP Gen5 4-80).')
param sqlMiVCores int = 8

@description('Optional Entra admin group object ID for MI management-plane admin.')
param sqlMiEntraAdminGroupObjectId string = ''

@description('Tags applied to every resource group.')
param tags object = {
  workload: 'i2-analyze'
  owner: 'Korin Taunton'
  costCentre: 'forensic-platform'
  environment: environment
}

var rgName = getResourceName('resourceGroup', workload, environment, '001')

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
  tags: tags
}

// Central private DNS zones already exist and are linked to the VNet.
// 4-arg resourceId (at subscription scope a 3-arg first value is read as a sub ID).
var dnsZoneVaultId = resourceId(subscription().subscriptionId, privateDnsResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')
var dnsZoneAcrId = resourceId(subscription().subscriptionId, privateDnsResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.azurecr.io')
#disable-next-line no-hardcoded-env-urls
var dnsZoneBlobId = resourceId(subscription().subscriptionId, privateDnsResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.core.windows.net')

module net 'modules/network-nsgs.bicep' = {
  name: 'i2-net-nsgs'
  scope: rg
  params: { workload: workload, environment: environment, location: location, tags: tags }
}

module subnets 'modules/network-subnets.bicep' = {
  name: 'i2-net-subnets'
  scope: resourceGroup(subscription().subscriptionId, existingVnetResourceGroupName)
  params: {
    existingVnetName: existingVnetName
    i2AddressPrefix: i2AddressPrefix
    aksNsgId: net.outputs.aksNsgId
    sqlMiNsgId: net.outputs.sqlMiNsgId
    sqlMiRouteTableId: net.outputs.sqlMiRouteTableId
  }
}

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
    subnetId: subnets.outputs.pepSubnetId
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
    subnetId: subnets.outputs.pepSubnetId
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
    subnetId: subnets.outputs.pepSubnetId
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
    nodeSubnetId: subnets.outputs.aksSubnetId
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
    subnetId: subnets.outputs.sqlMiSubnetId
    adminLogin: sqlMiAdminLogin
    adminPassword: sqlMiAdminPassword
    collation: sqlMiCollation
    vCores: sqlMiVCores
    entraAdminGroupObjectId: sqlMiEntraAdminGroupObjectId
    tags: tags
  }
}

output aksClusterName string = aks.outputs.clusterName
output acrLoginServer string = acr.outputs.loginServer
output keyVaultName string = keyVault.outputs.vaultName
output storageAccountName string = storage.outputs.storageAccountName
output workloadIdentityClientId string = workloadIdentity.outputs.clientId
output sqlManagedInstanceFqdn string = sqlMi.outputs.managedInstanceFqdn
