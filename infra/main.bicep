@description('Base name for resources (letters/numbers/hyphen). Example: ticket-guard')
param baseName string = 'ticket-guard'

@description('Environment fixed to poc for this proof-of-concept deployment (disposable).')
param environment string = 'poc'

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Python version')
@allowed(['3.11'])
param pythonVersion string = '3.11'

@description('Functions runtime major version')
@allowed(['4'])
param functionsVersion string = '4'

@description('Signing secret for HMAC token generation')
@secure()
param signingSecret string

@description('Purpose tag (e.g. poc, demo, staging, production). Defaults to poc for evaluation deployments.')
param purpose string = 'poc'

@description('Owner tag (contact: email or alias) who is responsible for this deployment.')
param owner string

@description('Expiry date (YYYY-MM-DD) after which this POC deployment can be safely deleted.')
param expiresOn string

// ---------- common tags (applied to every resource) ----------
var commonTags = {
  environment: environment
  purpose: purpose
  owner: owner
  expiresOn: expiresOn
  app: baseName
}

// ---------- naming helpers (environment first to highlight disposability: poc-ticket-guard-*) ----------
// Example (poc): function app -> poc-ticket-guard-func
var namePrefix = '${environment}-${baseName}'
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
// Storage account: must be <=24, lowercase, alphanumeric. Remove hyphens then concat.
// Pattern: poc + baseName (hyphens stripped) + env suffix first + unique
var storageName = toLower(replace('${environment}${baseName}${uniqueSuffix}', '-', ''))
var appInsightsName = '${namePrefix}-ai'
var planName = '${namePrefix}-plan'
var functionAppName = '${namePrefix}-func'

// ---------- storage (required by Functions) ----------
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  tags: commonTags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

// build connection string for AzureWebJobsStorage
var storageKey = listKeys(storage.id, '2023-01-01').keys[0].value
// For public Azure cloud. If sovereign clouds are needed later, replace EndpointSuffix accordingly or reintroduce environment() function under a different param name.
var storageConn = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storageKey};EndpointSuffix=core.windows.net'

// ---------- application insights ----------
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: commonTags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 90
  }
}

// ---------- consumption plan (linux) ----------
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: commonTags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true   // Linux
  }
}

// ---------- function app (linux, python) ----------
resource func 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  tags: commonTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Python|${pythonVersion}'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        // required
  { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'python' }
  { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~${functionsVersion}' }
  { name: 'AzureWebJobsStorage', value: storageConn }

        // deployment model: run from package (recommended)
  { name: 'WEBSITE_RUN_FROM_PACKAGE', value: '1' }

        // observability
  { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }

        // demo secret (use Key Vault later)
  { name: 'SIGNING_SECRET', value: signingSecret }
      ]
    }
  }
}

// ---------- outputs ----------
output functionAppName string = func.name
output functionAppHostname string = func.properties.defaultHostName
output functionAppUrl string = 'https://${func.properties.defaultHostName}'
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output storageAccountName string = storage.name
// Managed Identity principal (for Key Vault access to be added later)
output functionPrincipalId string = func.identity.principalId
// Tenant (handy for federated identity or documentation)
output tenantId string = subscription().tenantId
