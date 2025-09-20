@description('Base name prefix for all resources')
param baseName string = 'ticketguard'

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('SKU for the Function App plan (Y1 = Consumption)')
@allowed(['Y1'])
param planSku string = 'Y1'

@description('Runtime version for functions')
param functionsVersion string = '4'

@description('Python version for the Function App')
param pythonVersion string = '3.11'

// Naming helpers
var storageName = toLower(replace('${baseName}funcstore','-',''))
var appInsightsName = '${baseName}-ai'
var planName = '${baseName}-plan'
var functionAppName = '${baseName}-func'

// Storage account (required for Functions)
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

// Consumption plan (serverFarm)
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  sku: {
    name: planSku
    tier: 'Dynamic'
  }
  properties: {
    reserved: true // required for Linux
  }
}

// Function App (Linux, Python)
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'Python|${pythonVersion}'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storage.listKeys().keys[0].value
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~${functionsVersion}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        // Placeholder secret. Override via deployment slot/app settings or GitHub Actions secret.
        {
          name: 'SIGNING_SECRET'
          value: 'CHANGE_ME'
        }
      ]
      http20Enabled: true
      ftpsState: 'Disabled'
    }
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output functionAppName string = functionApp.name
output functionAppHostname string = functionApp.properties.defaultHostName
output appInsightsConnectionString string = appInsights.properties.ConnectionString
