// Log Analytics + Azure Monitor workspace (managed Prometheus) + Managed
// Grafana. Replaces the reference HAProxy/Prometheus/Grafana containers.
import { getResourceName, getResourceNameSimple } from '../naming/naming.bicep'
param workload string
param environment string
param location string
param grafanaAdminGroupObjectId string = '00000000-0000-0000-0000-000000000000'
param tags object

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: getResourceNameSimple('logAnalyticsWorkspace', workload, environment)
  location: location
  tags: tags
  properties: { sku: { name: 'PerGB2018' }, retentionInDays: 90 }
}

resource amw 'Microsoft.Monitor/accounts@2023-04-03' = {
  name: 'amw-${workload}-${environment}'
  location: location
  tags: tags
}

resource grafana 'Microsoft.Dashboard/grafana@2023-09-01' = {
  name: 'amg-${workload}-${environment}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  identity: { type: 'SystemAssigned' }
  properties: {
    grafanaIntegrations: { azureMonitorWorkspaceIntegrations: [ { azureMonitorWorkspaceResourceId: amw.id } ] }
  }
}

var grafanaAdminRoleId = '22926164-76b3-42b3-bc55-97df8dab3e41' // Grafana Admin
var hasAdminGroup = grafanaAdminGroupObjectId != '00000000-0000-0000-0000-000000000000'
resource grafanaAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (hasAdminGroup) {
  name: guid(grafana.id, grafanaAdminGroupObjectId, grafanaAdminRoleId)
  scope: grafana
  properties: {
    principalId: grafanaAdminGroupObjectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', grafanaAdminRoleId)
    principalType: 'Group'
  }
}

output logAnalyticsWorkspaceId string = law.id
output azureMonitorWorkspaceId string = amw.id
