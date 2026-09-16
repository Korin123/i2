// Azure SQL Managed Instance - the Information Store data tier (off containers).
// MI has SQL Agent, sysadmin/BULK INSERT and instance collation (the Information
// Store's instance requirements) plus built-in HA and backups.
// Prereqs: a dedicated subnet delegated to Microsoft.Sql/managedInstances with
// its own NSG and route table (see network modules); admin password from KV.
// IMMUTABLE at creation: collation. Confirm vs i2 4.4.x prerequisites first.
param workload string
param environment string
param location string
param subnetId string
param adminLogin string = 'i2miadmin'
@secure()
param adminPassword string
param collation string = 'Latin1_General_100_CI_AS'
@allowed([ 'GeneralPurpose', 'BusinessCritical' ])
param tier string = 'GeneralPurpose'
param vCores int = 8
param storageSizeInGB int = 512
@allowed([ 'LicenseIncluded', 'BasePrice' ])
param licenseType string = 'LicenseIncluded'
param zoneRedundant bool = true
@allowed([ 'LRS', 'ZRS', 'GRS' ])
param backupStorageRedundancy string = 'ZRS'
@allowed([ 'Proxy', 'Redirect' ])
param proxyOverride string = 'Proxy'
param entraAdminGroupObjectId string = ''
param tags object

var miName = toLower('sqlmi-${workload}-${environment}-001')

resource mi 'Microsoft.Sql/managedInstances@2023-08-01-preview' = {
  name: miName
  location: location
  tags: tags
  sku: { name: tier == 'BusinessCritical' ? 'BC_Gen5' : 'GP_Gen5', tier: tier, family: 'Gen5' }
  identity: { type: 'SystemAssigned' }
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    subnetId: subnetId
    licenseType: licenseType
    vCores: vCores
    storageSizeInGB: storageSizeInGB
    collation: collation
    publicDataEndpointEnabled: false
    minimalTlsVersion: '1.2'
    proxyOverride: proxyOverride
    zoneRedundant: zoneRedundant
    requestedBackupStorageRedundancy: backupStorageRedundancy
  }
}

resource entraAdmin 'Microsoft.Sql/managedInstances/administrators@2023-08-01-preview' = if (!empty(entraAdminGroupObjectId)) {
  parent: mi
  name: 'ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: 'i2-sqlmi-admins'
    sid: entraAdminGroupObjectId
    tenantId: tenant().tenantId
  }
}

output managedInstanceName string = mi.name
output managedInstanceFqdn string = mi.properties.fullyQualifiedDomainName
output managedInstanceId string = mi.id
