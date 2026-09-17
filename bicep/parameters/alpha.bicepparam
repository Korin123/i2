using '../main.bicep'

// Placeholders only. Real subscription/tenant/object IDs and the MI admin
// password are supplied at deploy time via pipeline variables - never here.
param workload = 'i2'
param environment = 'alpha'
param location = 'uksouth'

// Nothing exists in Azure for this environment yet, so Bicep creates the VNet and DNS zones.
// To attach to an existing VNet instead: networkMode = 'existing' and uncomment the three below.
param networkMode = 'new'
param i2AddressPrefix = '10.200.212.0/24'
// param existingVnetName = '<EXISTING_VNET_NAME>'
// param existingVnetResourceGroupName = '<EXISTING_VNET_RG>'
// param privateDnsResourceGroupName = '<PRIVATE_DNS_RG>'

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
// IMMUTABLE once the MI exists. Must equal Collation in the i2 config's
// InfoStoreNamesSQLServer.properties (scripts/30-build-images.sh prints both and warns).
param sqlMiCollation = 'Latin1_General_100_CI_AS'
param sqlMiVCores = 8
param sqlMiEntraAdminGroupObjectId = ''
