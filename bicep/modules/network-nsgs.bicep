// NSGs and the SQL MI route table (in the i2 RG). The VNet is external;
// i2 only owns these attachments. MI uses service-aided subnet config, so
// its NSG and route table exist and are associated but carry no manual rules.
import { getResourceName } from '../naming/naming.bicep'

param workload string
param environment string
param location string
param tags object

resource aksNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: getResourceName('networkSecurityGroup', '${workload}-aks', environment, '001')
  location: location
  tags: tags
}

resource sqlMiNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: getResourceName('networkSecurityGroup', '${workload}-sqlmi', environment, '001')
  location: location
  tags: tags
}

// No naming key for route tables - named manually per the naming reference.
resource sqlMiRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-${workload}-sqlmi-${environment}-001'
  location: location
  tags: tags
}

output aksNsgId string = aksNsg.id
output sqlMiNsgId string = sqlMiNsg.id
output sqlMiRouteTableId string = sqlMiRouteTable.id
