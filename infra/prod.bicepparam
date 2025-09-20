using './rg-only.bicep'

// Production environment parameters.
// Keep expiry blank or a far-future date; governance may enforce real timelines later.
// Secrets not yet in scope (Key Vault planned Phase2+).

param resourceGroupName = 'prod-ticket-guard-rg'
param location = 'japaneast'
param environment = 'prod'
param owner = 'shuji.miyoshi@willer.co.jp'
param expiresOn = '2099-12-31'
param purpose = 'prod'
param app = 'ticket-guard'
