// networkMode = 'new': the private DNS zones the private endpoints register in (Key Vault,
// ACR, Blob), linked to the i2 VNet. In 'existing' mode central zones are used instead.
param vnetId string
param tags object

#disable-next-line no-hardcoded-env-urls
var zoneNames = [ 'privatelink.vaultcore.azure.net', 'privatelink.azurecr.io', 'privatelink.blob.core.windows.net' ]

resource zones 'Microsoft.Network/privateDnsZones@2024-06-01' = [for z in zoneNames: {
  name: z
  location: 'global'
  tags: tags
}]

resource links 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (z, i) in zoneNames: {
  parent: zones[i]
  name: 'link-i2'
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: { id: vnetId }
    registrationEnabled: false
  }
}]

output vaultZoneId string = zones[0].id
output acrZoneId string = zones[1].id
output blobZoneId string = zones[2].id
