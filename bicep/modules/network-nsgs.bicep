// NSGs and the SQL MI route table (in the i2 RG). MI uses service-aided subnet configuration:
// when the MI is created, Azure adds its own rules to the MI NSG and routes to the MI route
// table. A later deployment that declares them again (with no rules) would remove those and is
// rejected, so they are only created when they do not exist yet (sqlMiNetworkExists, set by
// scripts/10-deploy-infra.sh), and referenced by ID otherwise.
import { getResourceName } from '../naming/naming.bicep'

param workload string
param environment string
param location string
@description('true when the SQL MI NSG and route table already exist: leave them to Azure.')
param sqlMiNetworkExists bool = false
param tags object

var sqlMiNsgName = getResourceName('networkSecurityGroup', '${workload}-sqlmi', environment, '001')
// No naming key for route tables - named manually per the naming reference.
var sqlMiRouteTableName = 'rt-${workload}-sqlmi-${environment}-001'

resource aksNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: getResourceName('networkSecurityGroup', '${workload}-aks', environment, '001')
  location: location
  tags: tags
}

resource sqlMiNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = if (!sqlMiNetworkExists) {
  name: sqlMiNsgName
  location: location
  tags: tags
}

resource sqlMiRouteTable 'Microsoft.Network/routeTables@2024-05-01' = if (!sqlMiNetworkExists) {
  name: sqlMiRouteTableName
  location: location
  tags: tags
}

output aksNsgId string = aksNsg.id
output sqlMiNsgId string = resourceId('Microsoft.Network/networkSecurityGroups', sqlMiNsgName)
output sqlMiRouteTableId string = resourceId('Microsoft.Network/routeTables', sqlMiRouteTableName)
