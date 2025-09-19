# ticket-guard

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

