// ============================================================================
// Azure CAF Resource Type Abbreviations
// Source: https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
// Korin Taunton.
// ============================================================================

@export()
var resourceAbbreviations = {
  // General
  managementGroup: { prefix: 'mg', maxLength: 90, allowHyphens: true }
  resourceGroup: { prefix: 'rg', maxLength: 90, allowHyphens: true }
  policyDefinition: { prefix: 'policy', maxLength: 128, allowHyphens: true }
  apiManagement: { prefix: 'apim', maxLength: 50, allowHyphens: true }

  // Networking
  virtualNetwork: { prefix: 'vnet', maxLength: 64, allowHyphens: true }
  subnet: { prefix: 'snet', maxLength: 80, allowHyphens: true }
  networkInterface: { prefix: 'nic', maxLength: 80, allowHyphens: true }
  publicIpAddress: { prefix: 'pip', maxLength: 80, allowHyphens: true }
  loadBalancerInternal: { prefix: 'lbi', maxLength: 80, allowHyphens: true }
  loadBalancerExternal: { prefix: 'lbe', maxLength: 80, allowHyphens: true }
  networkSecurityGroup: { prefix: 'nsg', maxLength: 80, allowHyphens: true }
  applicationSecurityGroup: { prefix: 'asg', maxLength: 80, allowHyphens: true }
  localNetworkGateway: { prefix: 'lgw', maxLength: 80, allowHyphens: true }
  virtualNetworkGateway: { prefix: 'vgw', maxLength: 80, allowHyphens: true }
  vpnConnection: { prefix: 'cn', maxLength: 80, allowHyphens: true }
  applicationGateway: { prefix: 'agw', maxLength: 80, allowHyphens: true }
  routeTable: { prefix: 'rt', maxLength: 80, allowHyphens: true }
  userDefinedRoute: { prefix: 'udr', maxLength: 80, allowHyphens: true }
  trafficManagerProfile: { prefix: 'traf', maxLength: 63, allowHyphens: true }
  frontDoor: { prefix: 'fd', maxLength: 64, allowHyphens: true }
  frontDoorFirewallPolicy: { prefix: 'fdfp', maxLength: 128, allowHyphens: true }
  cdnProfile: { prefix: 'cdnp', maxLength: 260, allowHyphens: true }
  cdnEndpoint: { prefix: 'cdne', maxLength: 50, allowHyphens: true }
  firewallPolicy: { prefix: 'afwp', maxLength: 80, allowHyphens: true }
  firewall: { prefix: 'afw', maxLength: 80, allowHyphens: true }
  expressRouteCircuit: { prefix: 'erc', maxLength: 80, allowHyphens: true }
  privateDnsZone: { prefix: 'pdnsz', maxLength: 63, allowHyphens: true }
  privateEndpoint: { prefix: 'pep', maxLength: 80, allowHyphens: true }
  privateLinkService: { prefix: 'pl', maxLength: 80, allowHyphens: true }
  bastionHost: { prefix: 'bas', maxLength: 80, allowHyphens: true }
  natGateway: { prefix: 'ng', maxLength: 80, allowHyphens: true }
  virtualWan: { prefix: 'vwan', maxLength: 80, allowHyphens: true }
  virtualHub: { prefix: 'vhub', maxLength: 80, allowHyphens: true }

  // Compute and Web
  virtualMachine: { prefix: 'vm', maxLength: 15, allowHyphens: true }
  virtualMachineScaleSet: { prefix: 'vmss', maxLength: 15, allowHyphens: true }
  availabilitySet: { prefix: 'avail', maxLength: 80, allowHyphens: true }
  managedDisk: { prefix: 'disk', maxLength: 80, allowHyphens: true }
  vmStorageAccount: { prefix: 'stvm', maxLength: 24, allowHyphens: false }
  webApp: { prefix: 'app', maxLength: 60, allowHyphens: true }
  staticWebApp: { prefix: 'stapp', maxLength: 40, allowHyphens: true }
  functionApp: { prefix: 'func', maxLength: 60, allowHyphens: true }
  appServicePlan: { prefix: 'asp', maxLength: 40, allowHyphens: true }
  appServiceEnvironment: { prefix: 'ase', maxLength: 36, allowHyphens: true }

  // Containers
  aksCluster: { prefix: 'aks', maxLength: 63, allowHyphens: true }
  containerRegistry: { prefix: 'cr', maxLength: 50, allowHyphens: false }
  containerInstance: { prefix: 'ci', maxLength: 63, allowHyphens: true }
  containerApp: { prefix: 'ca', maxLength: 32, allowHyphens: true }
  containerAppEnvironment: { prefix: 'cae', maxLength: 60, allowHyphens: true }

  // Databases
  sqlServer: { prefix: 'sql', maxLength: 63, allowHyphens: true }
  sqlDatabase: { prefix: 'sqldb', maxLength: 128, allowHyphens: true }
  sqlElasticPool: { prefix: 'sqlep', maxLength: 128, allowHyphens: true }
  sqlManagedInstance: { prefix: 'sqlmi', maxLength: 63, allowHyphens: true }
  cosmosDbAccount: { prefix: 'cosmos', maxLength: 44, allowHyphens: true }
  redisCacheInstance: { prefix: 'redis', maxLength: 63, allowHyphens: true }
  mySqlDatabase: { prefix: 'mysql', maxLength: 63, allowHyphens: true }
  postgreSqlDatabase: { prefix: 'psql', maxLength: 63, allowHyphens: true }

  // Storage
  storageAccount: { prefix: 'st', maxLength: 24, allowHyphens: false }
  storageAccountBlob: { prefix: 'stblob', maxLength: 24, allowHyphens: false }
  storageAccountFile: { prefix: 'stfile', maxLength: 24, allowHyphens: false }
  storageAccountQueue: { prefix: 'stq', maxLength: 24, allowHyphens: false }
  storageAccountTable: { prefix: 'sttbl', maxLength: 24, allowHyphens: false }
  azureNetAppFiles: { prefix: 'anf', maxLength: 80, allowHyphens: true }
  azureNetAppFilesCapacityPool: { prefix: 'anfcp', maxLength: 64, allowHyphens: true }
  azureNetAppFilesVolume: { prefix: 'anfvol', maxLength: 64, allowHyphens: true }

  // AI and Machine Learning
  cognitiveServicesAccount: { prefix: 'cog', maxLength: 64, allowHyphens: true }
  machineLearningWorkspace: { prefix: 'mlw', maxLength: 260, allowHyphens: true }
  openAiService: { prefix: 'oai', maxLength: 64, allowHyphens: true }
  searchService: { prefix: 'srch', maxLength: 60, allowHyphens: true }

  // Analytics and IoT
  dataFactory: { prefix: 'adf', maxLength: 63, allowHyphens: true }
  dataLakeStore: { prefix: 'dls', maxLength: 24, allowHyphens: false }
  dataLakeAnalytics: { prefix: 'dla', maxLength: 24, allowHyphens: false }
  dataExplorerCluster: { prefix: 'dec', maxLength: 22, allowHyphens: true }
  dataExplorerDatabase: { prefix: 'dedb', maxLength: 260, allowHyphens: true }
  databricksWorkspace: { prefix: 'dbw', maxLength: 30, allowHyphens: true }
  streamAnalytics: { prefix: 'asa', maxLength: 63, allowHyphens: true }
  eventHub: { prefix: 'evh', maxLength: 256, allowHyphens: true }
  eventHubNamespace: { prefix: 'evhns', maxLength: 256, allowHyphens: true }
  eventGridTopic: { prefix: 'evgt', maxLength: 50, allowHyphens: true }
  eventGridSubscription: { prefix: 'evgs', maxLength: 64, allowHyphens: true }
  iotHub: { prefix: 'iot', maxLength: 50, allowHyphens: true }

  // Integration
  serviceBusNamespace: { prefix: 'sbns', maxLength: 260, allowHyphens: true }
  serviceBusQueue: { prefix: 'sbq', maxLength: 260, allowHyphens: true }
  serviceBusTopic: { prefix: 'sbt', maxLength: 260, allowHyphens: true }
  logicApp: { prefix: 'logic', maxLength: 80, allowHyphens: true }

  // Developer Tools
  devTestLab: { prefix: 'lab', maxLength: 50, allowHyphens: true }
  devTestVm: { prefix: 'labvm', maxLength: 15, allowHyphens: true }

  // Identity
  managedIdentityUserAssigned: { prefix: 'id', maxLength: 128, allowHyphens: true }

  // Management and Governance
  automationAccount: { prefix: 'aa', maxLength: 50, allowHyphens: true }
  logAnalyticsWorkspace: { prefix: 'log', maxLength: 63, allowHyphens: true }
  applicationInsights: { prefix: 'appi', maxLength: 260, allowHyphens: true }
  actionGroup: { prefix: 'ag', maxLength: 260, allowHyphens: true }
  blueprint: { prefix: 'bp', maxLength: 90, allowHyphens: true }
  keyVault: { prefix: 'kv', maxLength: 24, allowHyphens: true }
  recoveryServicesVault: { prefix: 'rsv', maxLength: 50, allowHyphens: true }
  backupVault: { prefix: 'bvault', maxLength: 50, allowHyphens: true }

  // Virtual Desktop
  hostPool: { prefix: 'hp', maxLength: 64, allowHyphens: true }
  applicationGroup: { prefix: 'ag', maxLength: 64, allowHyphens: true }
  workspace: { prefix: 'ws', maxLength: 64, allowHyphens: true }
  scalingPlan: { prefix: 'sp', maxLength: 64, allowHyphens: true }
}
