using '../main.bicep'

// Placeholders only. Real subscription/tenant/object IDs and the MI admin
// password are supplied at deploy time via pipeline variables - never here.
param workload = 'i2'
param environment = 'alpha'
param location = 'uksouth'

param i2AddressPrefix = '10.200.212.0/24'
param existingVnetName = '<EXISTING_VNET_NAME>'
param existingVnetResourceGroupName = '<EXISTING_VNET_RG>'
param privateDnsResourceGroupName = '<PRIVATE_DNS_RG>'

// Entra group granted AKS + Grafana admin. Zeros placeholder is skipped.
param aksAdminGroupObjectId = '00000000-0000-0000-0000-000000000000'
param aksOutboundType = 'loadBalancer'

// Deployer SPN object ID - supply via pipeline variable, not committed.
param deployerObjectId = ''

// Public IPs allow-listed on KV/ACR for testing. Empty = private only.
param allowedTestIps = []

// SQL Managed Instance
param sqlMiAdminLogin = 'i2miadmin'
// sqlMiAdminPassword is a secure param - supplied by the pipeline from Key Vault.
param sqlMiCollation = 'Latin1_General_100_CI_AS'  // CONFIRM vs i2 4.4.x prereqs (immutable)
param sqlMiVCores = 8
param sqlMiEntraAdminGroupObjectId = ''
