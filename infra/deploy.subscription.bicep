// Subscription-scope deployment wrapper
// Purpose: Create (or ensure) the resource group, then deploy the existing main.bicep at resource group scope.
// This allows a single command (subscription deployment) without pre-creating the RG manually.
// NOTE: Keep PoC minimal. Key Vault integration will be added later in a separate module.

targetScope = 'subscription'

@description('Resource group name to create or update (idempotent).')
@minLength(3)
@maxLength(90)
param resourceGroupName string

@description('Azure region for the resource group & resources (must support all child resource types).')
param location string = 'japaneast'

@description('Base name for workload (aligned with existing main.bicep).')
param baseName string = 'ticket-guard'

@description('Environment name (poc only for now).')
@allowed(['poc'])
param environment string = 'poc'

@description('Owner tag (email or alias).')
param owner string

@description('Expiry date (YYYY-MM-DD) for lifecycle governance.')
param expiresOn string

@description('Purpose tag (fixed for PoC).')
param purpose string = 'poc'

@description('Signing secret for HMAC token generation (will move to Key Vault in a future step).')
@secure()
param signingSecret string

@description('Optional: expected subscription id. When provided, the deployment will expose `subscriptionMatches` output indicating whether the current deployment subscription matches the expected id.')
@maxLength(64)
param expectedSubscriptionId string = ''

// Common tags applied both at RG creation (so portal filters show them even if module fails) and to resources inside main.bicep
var commonTags = {
  environment: environment
  purpose: purpose
  owner: owner
  expiresOn: expiresOn
  app: baseName
}

// If caller provided an expected subscription id, compute whether current subscription matches.
var subscriptionMatches = empty(expectedSubscriptionId) || toLower(expectedSubscriptionId) == toLower(subscription().subscriptionId)

// Create / update the resource group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: commonTags
}

// Deploy existing resource-group scope template as a module
module app './main.bicep' = {
  scope: rg
  // (No module name property to follow latest best practices)
  params: {
    baseName: baseName
    environment: environment
    location: location
    owner: owner
    expiresOn: expiresOn
    signingSecret: signingSecret
    // purpose param in main.bicep defaults to 'poc'; can omit unless overriding
  }
}

// Bubble up outputs from the module for convenience
output functionAppName string = app.outputs.functionAppName
output functionAppHostname string = app.outputs.functionAppHostname
output functionAppUrl string = app.outputs.functionAppUrl
output appInsightsConnectionString string = app.outputs.appInsightsConnectionString
output storageAccountName string = app.outputs.storageAccountName
output functionPrincipalId string = app.outputs.functionPrincipalId
output tenantId string = app.outputs.tenantId

// Expose whether the current subscription matches the provided expectedSubscriptionId (if any).
output subscriptionMatches bool = subscriptionMatches
