# Ticket Guard - Azure Functions Token Issuance Service

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Overview
Ticket Guard is a Python-based Azure Functions application that provides secure token issuance with HMAC-SHA256 signatures. The service validates ticket and device IDs, generates time-limited tokens with nonces, and signs them cryptographically for verification.

## Working Effectively

### Bootstrap, Build, and Test the Repository
Always run these commands in sequence for a complete setup:

```bash
cd functions
python -m venv .venv                    # Takes 3 seconds. NEVER CANCEL.
source .venv/bin/activate              # Instant
pip install -r requirements.txt       # Takes 5-15 seconds depending on network. NEVER CANCEL.
pytest -q                             # Takes <1 second. Runs 18 tests.
mypy .                               # Takes 4 seconds. NEVER CANCEL.

**CRITICAL**: Set timeout to 60+ seconds for pip install command due to potential network delays.
**NEVER CANCEL any of these commands.** If pip install times out, network connectivity may be limited - document this in your changes.

**Network Limitation Workaround**: If pip install fails with timeout errors:
```bash
pip install --timeout 60 --retries 3 -r requirements.txt
```
If that also fails, document: "pip install fails due to network limitations" and use manual testing without full dependency installation.

**CRITICAL**: Network connectivity may be restricted in some environments. The limited testing workflow below works without any pip install dependencies.

### Environment Setup
Set the required environment variable for local testing:
```bash
export SIGNING_SECRET="your-strong-random-secret-here"
```
The secret is never logged and must be configured in Azure Function App settings for production.

### Running Tests
```bash
cd functions
source .venv/bin/activate
pytest -q           # Quick mode: 18 tests pass in 0.09s
pytest -v           # Verbose mode: Shows individual test results
```

### Type Checking
```bash
cd functions
source .venv/bin/activate
mypy .              # Takes 4 seconds. Should show "Success: no issues found"
```

### Manual Function Testing
Test the function directly without Azure Functions Core Tools (useful when dependencies fail to install):

**Basic Import Test**:
```bash
cd functions
python -c "
import sys
sys.path.append('.')
from IssueToken import main, validate_payload, sign, clamp_ttl
print('All functions imported successfully')
"
```

**Full Manual Test** (requires dependencies):
```bash
cd functions
source .venv/bin/activate
python -c "
import sys, json, os
sys.path.append('.')
import IssueToken as issue

os.environ['SIGNING_SECRET'] = 'test-secret'

class TestReq:
    def __init__(self, body_dict):
        self._body = json.dumps(body_dict).encode()
    def get_json(self):
        return json.loads(self._body.decode())

req = TestReq({'ticketId': 'TEST-001', 'deviceId': 'device-123', 'ttl': 10})
response = issue.main(req)
print(f'Status: {response.status_code}')
print(f'Body: {response._body}')
"
```

**Limited Testing Without Dependencies** (when pip install fails):
```bash
cd functions
python -c "
import sys, json, os, hmac, hashlib, base64, time
sys.path.append('.')

# Test core function imports
try:
    from IssueToken import validate_payload, clamp_ttl, sign
    print('✓ Core functions import successfully')
except ImportError as e:
    print(f'✗ Import failed: {e}')

# Test basic validation logic
try:
    payload = {'ticketId': 'TEST', 'deviceId': 'DEV', 'ttl': 10}
    result = validate_payload(payload)
    print(f'✓ Validation works: {result}')
except Exception as e:
    print(f'✗ Validation failed: {e}')

# Test TTL clamping
try:
    assert clamp_ttl(None) == 8, 'Default TTL should be 8'
    assert clamp_ttl(3) == 5, 'Low TTL should be clamped to 5'
    assert clamp_ttl(50) == 30, 'High TTL should be clamped to 30'
    print('✓ TTL clamping works correctly')
except Exception as e:
    print(f'✗ TTL clamping failed: {e}')
"
```

## Linting and Code Quality

### Flake8 Linting (Optional)
The CI uses flake8 for code style checking:
```bash
cd functions
source .venv/bin/activate
pip install flake8                   # Takes 2-3 seconds
flake8 --exclude=.venv .            # Takes <1 second. ALWAYS exclude .venv directory
```

**NOTE**: flake8 reports style violations but tests and functionality work correctly. The codebase currently has style issues but is fully functional.

## Azure Functions Core Tools (Optional)
**WARNING**: Installation requires internet access to Azure CDN:
```bash
npm install -g azure-functions-core-tools@4 --unsafe-perm true
```
If this fails due to network restrictions, use manual testing instead.

Local development with Azure Functions Core Tools:
```bash
cd functions
func start        # Starts local Azure Functions host
```

## Validation Scenarios

Always test these scenarios after making changes to the function logic:

### Valid Token Issuance
```json
POST /api/issue-token
{
  "ticketId": "EVENT-001",
  "deviceId": "mobile-123"
}
```
Expected: 200 status, JSON response with ticketId, deviceId, startAtEpochSec, ttlSec (8), nonce, and sig fields.

### Custom TTL
```json
POST /api/issue-token
{
  "ticketId": "EVENT-002", 
  "deviceId": "mobile-456",
  "ttl": 15
}
```
Expected: 200 status, ttlSec should be 15.

### Validation Errors (All should return 400)
1. **Missing ticketId**: `{"deviceId": "mobile-123"}`
2. **Pipe in ticketId**: `{"ticketId": "EVENT|001", "deviceId": "mobile-123"}`
3. **Pipe in deviceId**: `{"ticketId": "EVENT-001", "deviceId": "mobile|123"}`
4. **Invalid TTL**: `{"ticketId": "EVENT-001", "deviceId": "mobile-123", "ttl": 700}`

### Server Configuration Error
Test without SIGNING_SECRET environment variable:
Expected: 500 status, "Server misconfiguration" error.

## Repository Structure

### Key Files
- `functions/IssueToken/__init__.py` - Main Azure Function implementation
- `functions/IssueToken/function.json` - Azure Function binding configuration
- `functions/VerifyToken/__init__.py` - Token verification function (validates issued tokens)
- `functions/VerifyToken/function.json` - Verification function binding configuration
- `functions/tests/test_issue_token.py` - Comprehensive test suite (18 tests)
- `functions/requirements.txt` - Python dependencies (azure-functions, mypy, pytest)
- `functions/pyproject.toml` - Poetry configuration (alternative to requirements.txt)
- `functions/host.json` - Azure Functions runtime configuration
- `functions/local.settings.json` - Local development settings
- `functions/mypy.ini` - Type checking configuration
- `DEPLOYMENT.md` - Azure deployment guide
- `infra/main.bicep` - Infrastructure as code template

### Dependencies
- `azure-functions==1.18.0` - Azure Functions runtime bindings
- `mypy==1.11.2` - Static type checking
- `pytest==8.3.3` - Testing framework

## Code Architecture

### Core Functions
- `main(req)` - Main Azure Function entry point
- `validate_payload(payload)` - Input validation with pipe character checks
- `sign(secret, ticket_id, device_id, start_at, ttl, nonce)` - HMAC-SHA256 signature generation
- `clamp_ttl(ttl)` - TTL normalization (5-30 seconds, default 8)

### Key Constants
- `MIN_TTL = 5` - Minimum time-to-live seconds
- `MAX_TTL = 30` - Maximum time-to-live seconds  
- `DEFAULT_TTL = 8` - Default time-to-live seconds
- `NONCE_BYTES = 12` - Nonce length in bytes

### Validation Rules
- ticketId and deviceId cannot contain pipe characters (`|`)
- TTL must be integer between 1-600 (clamped to 5-30 for response)
- SIGNING_SECRET must be configured

## Common Tasks

The following are outputs from frequently run commands. Reference them instead of viewing, searching, or running bash commands to save time.

### Repository Root
```
$ ls -la
.git/
.github/            # GitHub workflows and this copilot-instructions.md file
.gitignore
.vscode/           # VS Code configuration
DEPLOYMENT.md      # Azure deployment quick reference
README.md          # Main project documentation
functions/         # Azure Functions implementation
infra/            # Infrastructure as Code (Bicep templates)
ios-demo/         # iOS demo application
```

### Functions Directory
```
$ ls -la functions/
IssueToken/          # Main token issuance function implementation
VerifyToken/         # Token verification function implementation  
tests/               # Test suite
host.json           # Azure Functions runtime config
local.settings.json # Local development settings
mypy.ini           # Type checking configuration  
pyproject.toml     # Poetry configuration
requirements.txt   # Python dependencies
```

### Requirements.txt
```
azure-functions==1.18.0
mypy==1.11.2
pytest==8.3.3
```

### README.md Summary
The README documents:
- API endpoint: POST /api/issue-token
- Request format: JSON with ticketId, deviceId, optional ttl
- Response format: JSON with ticket info, nonce, and HMAC signature
- Signature algorithm: HMAC-SHA256 with pipe-delimited message
- TTL clamping: 5-30 seconds (default 8)
- Environment variable: SIGNING_SECRET required
- Validation rules: No pipe characters in ticketId or deviceId

### After Making Code Changes
1. Run type checking: `mypy .`
2. Run tests: `pytest -q`
3. Test manually with various validation scenarios
4. Verify error handling and status codes

### Testing Signature Generation
The signature follows this format:
```
message = f"{ticketId}|{deviceId}|{startAtEpochSec}|{ttlSec}|{nonce}"
sig = base64url(HMAC_SHA256(SIGNING_SECRET, message))
```

### Debugging
- Check structured logs for events: `validation_failed`, `missing_signing_secret`, `token_issued`
- All validation errors return 400 with descriptive error messages
- Server configuration errors return 500

## Build Times and Timeouts
- Virtual environment creation: 3 seconds - Set timeout to 30+ seconds (10x buffer)
- Dependency installation: 5-15 seconds depending on network - Set timeout to 150+ seconds (10x buffer)  
- Test execution: <1 second (18 tests) - Set timeout to 10+ seconds (10x buffer)
- Type checking: 4 seconds - Set timeout to 40+ seconds (10x buffer)
- Manual testing: <1 second - Set timeout to 10+ seconds (10x buffer)

**Note:** All timeouts use a standardized 10x safety buffer to account for unexpected delays (e.g., network issues).
**CRITICAL**: Always use longer timeouts than needed. Network connectivity can cause delays.
**NEVER CANCEL** any development commands - they are essential for validation.

## Limitations
- Azure Functions Core Tools requires internet access to Azure CDN (may fail: `getaddrinfo ENOTFOUND cdn.functions.azure.com`)
- Poetry installation fails due to network restrictions - pip workflow is reliable alternative
- Pip install may fail or timeout due to network restrictions - use cached venv when possible
- CI/CD workflows exist (.github/workflows/) but are not for local development
- flake8 linting reports style issues but doesn't prevent functionality
- Function must be tested manually when Azure Functions Core Tools unavailable