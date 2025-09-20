import os
import json
import hmac as _hmac
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
        HttpRequest = DummyReq  # noqa: N815
        HttpResponse = DummyResp  # noqa: N815

MIMETYPE_JSON = "application/json"

logger = logging.getLogger("verify_token")
logger.setLevel(logging.INFO)

def _b64url(data: bytes) -> str:
    import base64
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def _expected_sig(secret: bytes, ticket_id: str, device_id: str, start_at: int, ttl: int, nonce: str) -> str:
    # Build message same as IssueToken.sign
    msg = f"{ticket_id}|{device_id}|{start_at}|{ttl}|{nonce}".encode()
    mac = _hmac.new(secret, msg, __import__("hashlib").sha256).digest()
    return _b64url(mac)

def validate_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    # Expect the full issued token fields
    required = ["ticketId", "deviceId", "startAtEpochSec", "ttlSec", "nonce", "sig"]
    for k in required:
        if k not in payload:
            raise ValueError(f"missing {k}")
    ticket = payload["ticketId"]
    device = payload["deviceId"]
    start = payload["startAtEpochSec"]
    ttl = payload["ttlSec"]
    nonce = payload["nonce"]
    sig = payload["sig"]
    if not isinstance(ticket, str) or not isinstance(device, str) or not isinstance(nonce, str) or not isinstance(sig, str):
        raise ValueError("invalid field types")
    if not isinstance(start, int) or not isinstance(ttl, int):
        raise ValueError("startAtEpochSec and ttlSec must be integers")
    return {"ticketId": ticket, "deviceId": device, "startAt": start, "ttl": ttl, "nonce": nonce, "sig": sig}

def main(req: 'func.HttpRequest') -> 'func.HttpResponse':  # type: ignore
    try:
        payload = req.get_json()
    except Exception:
        return func.HttpResponse(json.dumps({"error": "Invalid JSON"}), status_code=400, mimetype=MIMETYPE_JSON)

    try:
        data = validate_payload(payload)
    except ValueError as ve:
        logger.info("verify_validation_failed", extra={"reason": str(ve)})
        return func.HttpResponse(json.dumps({"valid": False, "reason": str(ve)}), status_code=400, mimetype=MIMETYPE_JSON)

    secret = os.environ.get("SIGNING_SECRET", "")
    if not secret:
        logger.error("missing_signing_secret")
        return func.HttpResponse(json.dumps({"error": "Server misconfiguration"}), status_code=500, mimetype=MIMETYPE_JSON)

    expected = _expected_sig(secret.encode(), data["ticketId"], data["deviceId"], data["startAt"], data["ttl"], data["nonce"])
    # constant-time compare
    if not _hmac.compare_digest(expected, data["sig"]):
        logger.info("verify_failed_sig", extra={"ticketId": data["ticketId"]})
        return func.HttpResponse(json.dumps({"valid": False, "reason": "signature_mismatch"}), status_code=200, mimetype=MIMETYPE_JSON)

    now = int(time.time())
    if data["startAt"] + data["ttl"] < now:
        logger.info("verify_failed_expired", extra={"ticketId": data["ticketId"]})
        return func.HttpResponse(json.dumps({"valid": False, "reason": "expired"}), status_code=200, mimetype=MIMETYPE_JSON)

    logger.info("verify_ok", extra={"ticketId": data["ticketId"], "deviceId": data["deviceId"]})
    return func.HttpResponse(json.dumps({"valid": True}), status_code=200, mimetype=MIMETYPE_JSON)
