// Phase0: Resource Group only deployment parameters (Bicep native format)
// NOTE: signingSecret is not used in this phase; retained in JSON file for historical reference (parameters.poc.json).
// Next phase: switch to subscription wrapper + modules.

param resourceGroupName = 'poc-ticket-guard-rg'
param location = 'japaneast'
// baseName removed for Phase0 (not a param in rg-only.bicep)
param environment = 'poc'
param owner = 'shuji.miyoshi@willer.co.jp'
param expiresOn = '2025-12-31'
param purpose = 'poc'
// param signingSecret = 'REPLACE-IN-PHASE1'  // intentionally commented out until Phase1
// Phase0: Resource Group only deployment parameters (Bicep native format)
// NOTE: signingSecret is not used in this phase; retained in JSON file for historical reference (parameters.poc.json).
// Next phase: switch to subscription wrapper + modules.

param resourceGroupName = 'poc-ticket-guard-rg'
param location = 'japaneast'
// baseName removed for Phase0 (not a param in rg-only.bicep)
param environment = 'poc'
param owner = 'shuji.miyoshi@willer.co.jp'
param expiresOn = '2025-12-31'
param purpose = 'poc'
// param signingSecret = 'REPLACE-IN-PHASE1'  // intentionally commented out until Phase1
using './rg-only.bicep'

// Phase0: Resource Group only deployment parameters (Bicep native format)
// NOTE: signingSecret is not used in this phase; retained in JSON file for historical reference (parameters.poc.json).
// Next phase: switch to subscription wrapper + modules.

param resourceGroupName = 'poc-ticket-guard-rg'
param location = 'japaneast'
// baseName removed for Phase0 (not a param in rg-only.bicep)
param environment = 'poc'
param owner = 'shuji.miyoshi@willer.co.jp'
param expiresOn = '2025-12-31'
param purpose = 'poc'
// param signingSecret = 'REPLACE-IN-PHASE1'  // intentionally commented out until Phase1
