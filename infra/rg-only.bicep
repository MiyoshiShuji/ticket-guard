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

@description('Environment tag (fixed to poc for this phase).')
@allowed(['poc'])
param environment string = 'poc'

@description('Owner contact (email or alias).')
param owner string

@description('Expiry date (YYYY-MM-DD) — after this date you may delete the RG.')
param expiresOn string

@description('Purpose tag (kept simple).')
param purpose string = 'poc'

@description('Base application name used for tagging.')
param app string = 'ticket-guard'

// Common tags (adjust here once; all resources later should follow the same set)
var tags = {
  environment: environment
  purpose: purpose
  owner: owner
  expiresOn: expiresOn
  app: app
}

// Create or update the resource group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

output resourceGroupName string = rg.name
output location string = rg.location
output appliedTags object = rg.tags
