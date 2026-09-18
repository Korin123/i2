// Adds the i2 subnets to the EXISTING VNet as child resources. Subnet writes
// on one VNet must be serialised (Azure rejects parallel changes), so the
// chain uses dependsOn. CIDRs derive from the i2 /24.
param existingVnetName string
param i2AddressPrefix string
param aksNsgId string
param sqlMiNsgId string
param sqlMiRouteTableId string

resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${existingVnetName}/snet-i2-aks'
  properties: {
    addressPrefix: cidrSubnet(i2AddressPrefix, 25, 0)   // .0/25
    networkSecurityGroup: { id: aksNsgId }
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

resource pepSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${existingVnetName}/snet-i2-pep'
  properties: {
    addressPrefix: cidrSubnet(i2AddressPrefix, 27, 4)   // .128/27
    privateEndpointNetworkPolicies: 'Disabled'
  }
  dependsOn: [ aksSubnet ]
}

resource enrichSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${existingVnetName}/snet-i2-enrich'
  properties: {
    addressPrefix: cidrSubnet(i2AddressPrefix, 28, 10)  // .160/28
  }
  dependsOn: [ pepSubnet ]
}

resource sqlMiSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${existingVnetName}/snet-i2-sqlmi'
  properties: {
    addressPrefix: cidrSubnet(i2AddressPrefix, 27, 6)   // .192/27
    delegations: [ { name: 'miDelegation', properties: { serviceName: 'Microsoft.Sql/managedInstances' } } ]
    networkSecurityGroup: { id: sqlMiNsgId }
    routeTable: { id: sqlMiRouteTableId }
    privateEndpointNetworkPolicies: 'Disabled'
  }
  dependsOn: [ enrichSubnet ]
}

output aksSubnetId string = aksSubnet.id
output pepSubnetId string = pepSubnet.id
output enrichSubnetId string = enrichSubnet.id
output sqlMiSubnetId string = sqlMiSubnet.id

// Azure DevOps agents in the VNet (Managed DevOps Pool): secrets, workload and sanity stages
resource agentsSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${existingVnetName}/snet-i2-agents'
  properties: {
    addressPrefix: cidrSubnet(i2AddressPrefix, 27, 7)   // .224/27
    // Managed DevOps Pool (VNet-injected agents) requires this delegation
    delegations: [ { name: 'devOpsPools', properties: { serviceName: 'Microsoft.DevOpsInfrastructure/pools' } } ]
  }
  dependsOn: [ sqlMiSubnet ]
}

output agentsSubnetId string = agentsSubnet.id
