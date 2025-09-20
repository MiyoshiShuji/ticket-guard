# ticket-guard

[![CI](https://github.com/MiyoshiShuji/ticket-guard/workflows/ci/badge.svg)](https://github.com/MiyoshiShuji/ticket-guard/actions/workflows/ci.yml)
[![Deploy](https://github.com/MiyoshiShuji/ticket-guard/workflows/Deploy%20to%20Azure/badge.svg)](https://github.com/MiyoshiShuji/ticket-guard/actions/workflows/deploy.yml)

## /api/issue-token (Azure Function)

HTTP POST `https://<your-function-app>.azurewebsites.net/api/issue-token?code=<function_key>`

Request JSON body:

```
{
	"ticketId": "string (required)",
	"deviceId": "string (required)",
	"ttl": 8   // optional seconds, clamped to 5..30, default 8
}
```

Response JSON:
```
{
	"ticketId": "...",
	"deviceId": "...",
	"startAtEpochSec": 1700000000,
	"ttlSec": 8,
	"nonce": "base64url",
	"sig": "base64url(hmacSHA256(secret, "ticketId|deviceId|startAt|ttl|nonce"))"
}
```

### Signature Details
```
message = f"{ticketId}|{deviceId}|{startAtEpochSec}|{ttlSec}|{nonce}".encode()
sig = base64url( HMAC_SHA256( SIGNING_SECRET, message ) )

禁止文字: `ticketId` / `deviceId` に区切り文字 `|` は使用禁止 (署名メッセージ分解曖昧化防止)
```

### Environment Variable
Set `SIGNING_SECRET` (strong random secret) in Function App configuration. It's never written to logs.

### Local Development
```
cd functions
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
func start  # if Azure Functions Core Tools installed
```

Test:
```
pytest -q
```

### Notes
- TTL less than 5 -> 5; greater than 30 -> 30; absent -> 8.
- Nonce is 12 random bytes base64url (no padding).
- Structured log events: `validation_failed`, `missing_signing_secret`, `token_issued`.

### Verification Example (Python)
```python
import hmac, hashlib, base64

def b64url(data: bytes) -> str:
	return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def verify(secret: str, ticket_id: str, device_id: str, start_at: int, ttl: int, nonce: str, sig: str) -> bool:
	msg = f"{ticket_id}|{device_id}|{start_at}|{ttl}|{nonce}".encode()
	expected = b64url(hmac.new(secret.encode(), msg, hashlib.sha256).digest())
	# 固定時間比較を推奨 (hmac.compare_digest)
	return hmac.compare_digest(expected, sig)
```

## Azure Deployment

### Prerequisites

1. **Azure Resources**:
   - Azure subscription
   - Resource group for the deployment
   
2. **GitHub OIDC Setup**:
   - Service Principal with federated credential for GitHub Actions
   - Contributor access to the target resource group

3. **Repository Secrets** (configured in GitHub repo settings):
   - `AZURE_CLIENT_ID` - Service Principal client ID
   - `AZURE_TENANT_ID` - Azure tenant ID
   - `AZURE_SUBSCRIPTION_ID` - Azure subscription ID
   - `AZURE_RESOURCE_GROUP` - Target resource group name
   - `APP_BASENAME` - Base name for resources (e.g., "ticket-guard")
   - `SIGNING_SECRET` - Strong random secret for HMAC signing

### Setup Guide

1. **Create Azure Service Principal with OIDC**:
```bash
# Create service principal
az ad sp create-for-rbac --name "github-actions-ticket-guard" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}

# Note the output: appId (client ID), tenant
```

2. **Create Federated Credential**:
```bash
az ad app federated-credential create \
  --id {client-id} \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:MiyoshiShuji/ticket-guard:ref:refs/heads/main",
    "description": "GitHub Actions OIDC for main branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

3. **Configure Repository Secrets** in GitHub Settings > Secrets and variables > Actions

4. **Deploy**:
   - Push to `main` branch to trigger automatic deployment
   - Or manually trigger via Actions tab > Deploy to Azure > Run workflow

### Infrastructure

The deployment creates:
- **Storage Account** - Azure Functions runtime storage
- **Application Insights** - Monitoring and logging
- **App Service Plan** - Consumption (serverless) plan
- **Function App** - Python 3.11 runtime with security settings

See `infra/README.md` for detailed infrastructure documentation.

### Function Endpoint

After deployment, the function will be available at:
```
POST https://{app-name}.azurewebsites.net/api/issue-token?code={function-key}
```

The function key is captured during deployment and displayed in the workflow logs.

