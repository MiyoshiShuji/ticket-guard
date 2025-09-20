# Azure Functions Deployment Quick Reference

## 🚀 Quick Deployment Steps

1. **Azure Setup (One-time)**:
   ```bash
   # Create resource group
   az group create --name rg-ticket-guard-prod --location eastus
   
   # Create service principal for GitHub Actions
   az ad sp create-for-rbac --name "github-actions-ticket-guard" \
     --role contributor \
     --scopes /subscriptions/{subscription-id}/resourceGroups/rg-ticket-guard-prod
   ```

2. **GitHub OIDC Setup (One-time)**:
   ```bash
   # Create federated credential for main branch
   az ad app federated-credential create \
     --id {client-id-from-step-1} \
     --parameters '{
       "name": "github-actions-main",
       "issuer": "https://token.actions.githubusercontent.com",
       "subject": "repo:MiyoshiShuji/ticket-guard:ref:refs/heads/main",
       "description": "GitHub Actions OIDC for main branch",
       "audiences": ["api://AzureADTokenExchange"]
     }'
   ```

3. **Repository Secrets** (GitHub Settings > Secrets and variables > Actions):
   - `AZURE_CLIENT_ID` - Service Principal client ID (appId from step 1)
   - `AZURE_TENANT_ID` - Azure tenant ID (tenant from step 1)  
   - `AZURE_SUBSCRIPTION_ID` - Your Azure subscription ID
   - `AZURE_RESOURCE_GROUP` - `rg-ticket-guard-prod` 
   - `APP_BASENAME` - `ticket-guard`
   - `SIGNING_SECRET` - Strong random secret (minimum 32 characters)

4. **Deploy**:
   - Push to `main` branch → Auto-deploy
   - Or manually: Actions tab > "Deploy to Azure" > Run workflow

## 📋 Verification Checklist

After deployment:
- [ ] Function App created: `ticket-guard-prod-func-{suffix}`
- [ ] Endpoint responds: `POST https://{app-name}.azurewebsites.net/api/issue-token?code={key}`
- [ ] Function key captured in workflow logs
- [ ] Application Insights logging works
- [ ] Health check returns 200 status

## 🔧 Infrastructure Details

**Resources Created**:
- Storage Account: `ticketguardprod{suffix}` (Functions runtime)
- Application Insights: `ticket-guard-prod-insights` (Monitoring)
- App Service Plan: `ticket-guard-prod-plan` (Consumption/Serverless)
- Function App: `ticket-guard-prod-func` (Python 3.11)

**Configuration**:
- Runtime: Python 3.11 on Linux
- Plan: Consumption (pay-per-execution)
- Security: HTTPS only, TLS 1.2, FTPS only
- Monitoring: Application Insights enabled

## 🧪 Testing

**Local Testing**:
```bash
cd functions
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export SIGNING_SECRET="test-secret"
pytest -v
```

**Remote Testing**:
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"ticketId": "TEST-001", "deviceId": "test-device"}' \
  "https://{app-name}.azurewebsites.net/api/issue-token?code={function-key}"
```

## 🔑 Function Key

Function key is automatically retrieved during deployment and shown in workflow logs.
To get it manually:
```bash
az functionapp keys list \
  --name {function-app-name} \
  --resource-group {resource-group} \
  --query "functionKeys.default" \
  --output tsv
```

## 🔄 CI/CD Pipeline

**Triggers**:
- Push to `main` with changes in `functions/`, `infra/`, or workflow
- Manual workflow dispatch with environment selection

**Pipeline Steps**:
1. **Infrastructure** - Deploy Bicep template
2. **Function** - Build, test, and deploy Python function  
3. **Verification** - Test endpoint and capture function key

**Environments**: dev, staging, prod (configurable via workflow dispatch)