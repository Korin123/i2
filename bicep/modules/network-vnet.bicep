// networkMode = 'new': a VNet for i2 in the i2 resource group, with the same subnets and
// CIDRs as the 'existing' mode (network-subnets.bicep). Subnets are declared inline so a
// re-deployment keeps them (a VNet re-deployed without its subnets would try to remove them).
import { getResourceName } from '../naming/naming.bicep'
param workload string
param environment string
param location string
param addressPrefix string
param aksNsgId string
param sqlMiNsgId string
param sqlMiRouteTableId string
param tags object

// Outbound internet for the self-hosted agents (new VNets get no default outbound access):
// the agents reach Azure DevOps, package mirrors and Docker Hub through this NAT gateway.
resource agentsNatIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: getResourceName('publicIpAddress', '${workload}-agents', environment, '001')
  location: location
  tags: tags
  sku: { name: 'Standard' }
  zones: [ '1', '2', '3' ]
  properties: { publicIPAllocationMethod: 'Static' }
}

resource agentsNat 'Microsoft.Network/natGateways@2024-05-01' = {
  name: getResourceName('natGateway', '${workload}-agents', environment, '001')
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    publicIpAddresses: [ { id: agentsNatIp.id } ]
    idleTimeoutInMinutes: 10
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: getResourceName('virtualNetwork', workload, environment, '001')
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [ addressPrefix ] }
    subnets: [
      {
        name: 'snet-i2-aks'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 25, 0)    // .0/25
          networkSecurityGroup: { id: aksNsgId }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-i2-pep'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 27, 4)    // .128/27
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-i2-enrich'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 28, 10)   // .160/28
        }
      }
      {
        name: 'snet-i2-sqlmi'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 27, 6)    // .192/27
          delegations: [ { name: 'miDelegation', properties: { serviceName: 'Microsoft.Sql/managedInstances' } } ]
          networkSecurityGroup: { id: sqlMiNsgId }
          routeTable: { id: sqlMiRouteTableId }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        // Azure DevOps agents in the VNet (Managed DevOps Pool): secrets, workload and sanity stages
        name: 'snet-i2-agents'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 27, 7)    // .224/27
          natGateway: { id: agentsNat.id }
          // Managed DevOps Pool (VNet-injected agents) requires this delegation
          delegations: [ { name: 'devOpsPools', properties: { serviceName: 'Microsoft.DevOpsInfrastructure/pools' } } ]
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output aksSubnetId string = '${vnet.id}/subnets/snet-i2-aks'
output pepSubnetId string = '${vnet.id}/subnets/snet-i2-pep'
output enrichSubnetId string = '${vnet.id}/subnets/snet-i2-enrich'
output sqlMiSubnetId string = '${vnet.id}/subnets/snet-i2-sqlmi'
output agentsSubnetId string = '${vnet.id}/subnets/snet-i2-agents'
