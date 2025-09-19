import os
import json
import base64
import hmac
import hashlib
import logging
import time
from typing import Any, Dict

try:
    import azure.functions as func  # type: ignore
except ImportError:  # allow tests without azure-functions runtime
    class DummyReq:  # minimal stand-ins
        def __init__(self, body: bytes):
            self._body = body
        def get_json(self):
            return json.loads(self._body.decode())
    class DummyResp:
        def __init__(self, body: str, status_code: int, mimetype: str):
            self._body = body; self.status_code = status_code; self.mimetype = mimetype
    class func:  # type: ignore
        HttpRequest = DummyReq  # noqa: N815 (keep azure style names for compatibility)
        HttpResponse = DummyResp  # noqa: N815

MIN_TTL = 5
MAX_TTL = 30
DEFAULT_TTL = 8
NONCE_BYTES = 12
MIMETYPE_JSON = "application/json"

logger = logging.getLogger("issue_token")
logger.setLevel(logging.INFO)

class ValidationError(ValueError):
    """Raised for user input validation errors."""
    pass

def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def clamp_ttl(ttl: int | None) -> int:
    if ttl is None:
        return DEFAULT_TTL
    return max(MIN_TTL, min(MAX_TTL, ttl))

def validate_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    ticket_id = payload.get("ticketId")
    device_id = payload.get("deviceId")
    ttl = payload.get("ttl")
    if not isinstance(ticket_id, str) or not ticket_id:
        raise ValidationError("ticketId must be non-empty string")
    if not isinstance(device_id, str) or not device_id:
        raise ValidationError("deviceId must be non-empty string")
    if ttl is not None and (not isinstance(ttl, int) or ttl <= 0 or ttl > 600):  # raw ttl sanity upper hard cap
        raise ValidationError("ttl must be int 1..600 if provided")
    return {"ticketId": ticket_id, "deviceId": device_id, "ttl": ttl}

def sign(secret: bytes, ticket_id: str, device_id: str, start_at: int, ttl: int, nonce: str) -> str:
    msg = f"{ticket_id}|{device_id}|{start_at}|{ttl}|{nonce}".encode()
    mac = hmac.new(secret, msg, hashlib.sha256).digest()
    return _b64url(mac)

def main(req: 'func.HttpRequest') -> 'func.HttpResponse':  # type: ignore
    try:
        payload = req.get_json()
    except Exception:
        return func.HttpResponse(json.dumps({"error": "Invalid JSON"}), status_code=400, mimetype=MIMETYPE_JSON)

    try:
        data = validate_payload(payload)
    except ValidationError as ve:
        logger.info("validation_failed", extra={"reason": str(ve)})
        return func.HttpResponse(json.dumps({"error": str(ve)}), status_code=400, mimetype=MIMETYPE_JSON)

    ttl_clamped = clamp_ttl(data["ttl"])
    start_at = int(time.time())
    nonce = _b64url(os.urandom(NONCE_BYTES))
    secret = os.environ.get("SIGNING_SECRET", "")
    if not secret:
        logger.error("missing_signing_secret")
        return func.HttpResponse(json.dumps({"error": "Server misconfiguration"}), status_code=500, mimetype=MIMETYPE_JSON)

    sig = sign(secret.encode(), data["ticketId"], data["deviceId"], start_at, ttl_clamped, nonce)

    response_obj = {
        "ticketId": data["ticketId"],
        "deviceId": data["deviceId"],
        "startAtEpochSec": start_at,
        "ttlSec": ttl_clamped,
        "nonce": nonce,
        "sig": sig,
    }

    logger.info("token_issued", extra={"ticketId": data["ticketId"], "deviceId": data["deviceId"], "ttlSec": ttl_clamped})
    return func.HttpResponse(json.dumps(response_obj), status_code=200, mimetype=MIMETYPE_JSON)
