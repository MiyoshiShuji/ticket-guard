# Azure Functions Infrastructure

This directory contains the Azure Bicep templates for deploying the ticket-guard Azure Functions infrastructure.

## Files

- `main.bicep` - Main infrastructure template that creates:
  - Storage Account (required for Azure Functions)
  - Application Insights (monitoring and logging)
  - App Service Plan (Consumption/serverless plan)
  - Function App with proper configuration
- `parameters.example.json` - Example parameters file

## Resources Created

1. **Storage Account** - Required for Azure Functions runtime and file storage
2. **Application Insights** - Monitoring, logging, and telemetry
3. **App Service Plan (Consumption)** - Serverless hosting plan for cost-effective scaling
4. **Function App** - The Azure Functions host with:
   - Python 3.11 runtime
   - HTTPS-only access
   - CORS configured for Azure Portal
   - Proper security settings (TLS 1.2, FTPS only)
   - Environment variables including `SIGNING_SECRET`

## Parameters

- `appBaseName` (string) - Base name for all resources (default: "ticket-guard")
- `location` (string) - Azure region (default: resource group location)
- `environment` (string) - Environment suffix like "dev", "staging", "prod" (default: "prod")
- `signingSecret` (secure string) - Secret key for HMAC token signing (required)

## Deployment

The infrastructure is deployed automatically via GitHub Actions. See the main README for setup instructions.

For manual deployment:

```bash
# Login to Azure
az login

# Create resource group (if needed)
az group create --name rg-ticket-guard-prod --location eastus

# Deploy infrastructure
az deployment group create \
  --resource-group rg-ticket-guard-prod \
  --template-file main.bicep \
  --parameters appBaseName=ticket-guard environment=prod signingSecret=your-secret
```

## Outputs

The template outputs:
- `functionAppName` - Name of the created Function App
- `functionAppHostName` - FQDN of the Function App
- `functionAppUrl` - Full HTTPS URL to the Function App
- `resourceGroupName` - Name of the resource group
- `storageAccountName` - Name of the storage account
- `appInsightsName` - Name of Application Insights instance