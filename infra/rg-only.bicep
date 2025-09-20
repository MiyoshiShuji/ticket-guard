// Minimal subscription-scope Bicep to create just a resource group for the PoC.
// Later steps will deploy workloads into this RG using other templates.
// Keep this file intentionally tiny for beginner clarity.

targetScope = 'subscription'

@description('Name of the resource group to create (idempotent).')
@minLength(3)
@maxLength(90)
param resourceGroupName string

@description('Azure region for the resource group.')
param location string = 'japaneast'

@description('Environment name. PoC phase supports poc and prod (prod has no automatic expiry).')
@allowed(['poc', 'prod'])
param environment string = 'poc'

@description('Owner contact (email or alias).')
param owner string

@description('Expiry date (YYYY-MM-DD) — after this date you may delete the RG.')
param expiresOn string

@description('Purpose tag (kept simple).')
param purpose string = 'poc'

@description('Base application name used for tagging.')
param app string = 'ticket-guard'

@description('Optional: expected subscription id. When provided, the template will expose a boolean output `subscriptionMatches` indicating whether the current deployment subscription matches the expected value. This helps avoid accidental deploys to the wrong subscription.')
@maxLength(64)
param expectedSubscriptionId string = ''

// Common tags (adjust here once; all resources later should follow the same set)
var tags = {
  environment: environment
  purpose: purpose
  owner: owner
  expiresOn: expiresOn
  app: app
}

// If caller provided an expected subscription id, compute whether current subscription matches.
var subscriptionMatches = empty(expectedSubscriptionId) || toLower(expectedSubscriptionId) == toLower(subscription().subscriptionId)

// Create or update the resource group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Expose whether the current subscription matches the expected id, if provided.
output subscriptionMatches bool = subscriptionMatches

output resourceGroupName string = rg.name
output location string = rg.location
output appliedTags object = rg.tags
