import os
import json
import base64
import sys
from pathlib import Path

# Add functions root to sys.path so IssueToken package is discoverable
sys.path.append(str(Path(__file__).resolve().parents[1]))
import IssueToken as issue  # type: ignore
import pytest

class DummyReq:
    def __init__(self, body_dict):
        self._body = json.dumps(body_dict).encode()
    def get_json(self):
        return json.loads(self._body.decode())

def parse_body(resp):
    if hasattr(resp, 'get_body'):
        return json.loads(resp.get_body().decode())  # azure.functions.HttpResponse
    return json.loads(resp._body)  # fallback dummy

def fixed_nonce():
    return base64.urlsafe_b64encode(b"123456789012").rstrip(b"=").decode()

def test_ttl_clamp_default(monkeypatch):
    # 目的: ttl を指定しない場合にデフォルト値 (DEFAULT_TTL=8) が適用されることを確認する
    # 期待値: レスポンスの ttlSec が 8
    monkeypatch.setenv("SIGNING_SECRET", "secret")
    req = DummyReq({"ticketId": "t1", "deviceId": "d1"})
    resp = issue.main(req)
    body = parse_body(resp)
    assert body["ttlSec"] == issue.DEFAULT_TTL


def test_ttl_clamp_low(monkeypatch):
    # 目的: 最小値未満 (1) を指定した場合に下限 (MIN_TTL=5) にクランプされることを確認
    # 期待値: ttlSec == 5
    monkeypatch.setenv("SIGNING_SECRET", "secret")
    req = DummyReq({"ticketId": "t1", "deviceId": "d1", "ttl": 1})
    resp = issue.main(req)
    body = parse_body(resp)
    assert body["ttlSec"] == issue.MIN_TTL


def test_ttl_clamp_high(monkeypatch):
    # 目的: 上限値 (30) を超える値 (100) を指定した場合に上限にクランプされることを確認
    # 期待値: ttlSec == 30
    monkeypatch.setenv("SIGNING_SECRET", "secret")
    req = DummyReq({"ticketId": "t1", "deviceId": "d1", "ttl": 100})  # > 30 but < validation hard cap
    resp = issue.main(req)
    body = parse_body(resp)
    assert body["ttlSec"] == issue.MAX_TTL


def test_signature_deterministic(monkeypatch):
    # 目的: 時刻と nonce を固定したとき HMAC 署名が決定的に再現できることを確認
    # 条件: time=1000 固定, urandom= 'A' * NONCE_BYTES
    # 期待値: nonce と sig が手計算 (期待算出) の値と一致
    monkeypatch.setenv("SIGNING_SECRET", "secret")
    # Freeze time
    monkeypatch.setattr(issue.time, "time", lambda: 1000)
    # Force nonce bytes
    monkeypatch.setattr(issue.os, "urandom", lambda n: b"A" * n)

    req = DummyReq({"ticketId": "TICK", "deviceId": "DEV", "ttl": 10})
    resp = issue.main(req)
    body = parse_body(resp)

    expected_nonce = issue._b64url(b"A" * issue.NONCE_BYTES)
    assert body["nonce"] == expected_nonce
    expected_sig = issue.sign(b"secret", "TICK", "DEV", 1000, 10, expected_nonce)
    assert body["sig"] == expected_sig


@pytest.mark.parametrize(
    "ticket_id,device_id,start_at,ttl,nonce,secret,modifier,should_match",
    [
        # 目的: すべて同一条件 -> 署名一致
        # 期待値: should_match=True
        ("EVT2025-0001", "device-ios-001", 1710000000, 8, "nonceBase", "primarySecret", None, True),
        # 目的: ticketId 違い -> 不一致
        ("EVT2025-0001", "device-ios-001", 1710000000, 8, "nonceBase", "primarySecret", {"ticket_id": "EVT2025-0002"}, False),
        # 目的: deviceId 違い -> 不一致
        ("EVT2025-0001", "device-ios-001", 1710000000, 8, "nonceBase", "primarySecret", {"device_id": "device-android-777"}, False),
        # 目的: startAt 違い -> 不一致
        ("EVT2025-0001", "device-ios-001", 1710000000, 8, "nonceBase", "primarySecret", {"start_at": 1710000001}, False),
        # 目的: ttl 違い -> 不一致
        ("EVT2025-0001", "device-ios-001", 1710000000, 8, "nonceBase", "primarySecret", {"ttl": 9}, False),
        # 目的: nonce 違い -> 不一致
        ("EVT2025-0001", "device-ios-001", 1710000000, 8, "nonceBase", "primarySecret", {"nonce": "nonceDiff"}, False),
        # 目的: secret 違い -> 不一致
        ("EVT2025-0001", "device-ios-001", 1710000000, 8, "nonceBase", "primarySecret", {"secret": b"secondarySecret"}, False),
    ],
)
def test_signature_matrix(ticket_id, device_id, start_at, ttl, nonce, secret, modifier, should_match):
    # 目的: 署名生成要素のどれか 1 つでも変化すれば HMAC 署名は一致しないことを網羅的に確認
    # 期待値: should_match フラグ通りに比較結果が一致/不一致になる
    base_sig = issue.sign(secret.encode() if isinstance(secret, str) else secret, ticket_id, device_id, start_at, ttl, nonce)

    # 変更適用
    if modifier:
        ticket_id2 = modifier.get("ticket_id", ticket_id)
        device_id2 = modifier.get("device_id", device_id)
        start_at2 = modifier.get("start_at", start_at)
        ttl2 = modifier.get("ttl", ttl)
        nonce2 = modifier.get("nonce", nonce)
        secret2 = modifier.get("secret", secret)
    else:
        ticket_id2, device_id2, start_at2, ttl2, nonce2, secret2 = ticket_id, device_id, start_at, ttl, nonce, secret

    sig2 = issue.sign(secret2.encode() if isinstance(secret2, str) else secret2, ticket_id2, device_id2, start_at2, ttl2, nonce2)

    if should_match:
        assert base_sig == sig2
    else:
        assert base_sig != sig2


def test_error_missing_ticket_id(monkeypatch):
    # 目的: ticketId 欠如時に 400 と適切なエラーメッセージが返ることを確認
    # 期待値: status_code == 400, エラーメッセージに 'ticketId'
    monkeypatch.setenv("SIGNING_SECRET", "secret")
    req = DummyReq({"deviceId": "d1"})
    resp = issue.main(req)
    body = parse_body(resp)
    assert resp.status_code == 400
    assert "ticketId" in body["error"]


def test_error_empty_device_id(monkeypatch):
    # 目的: deviceId が空文字のとき 400 エラーになることを確認
    # 期待値: status_code == 400, 'deviceId' を含むエラー
    monkeypatch.setenv("SIGNING_SECRET", "secret")
    req = DummyReq({"ticketId": "t1", "deviceId": ""})
    resp = issue.main(req)
    body = parse_body(resp)
    assert resp.status_code == 400
    assert "deviceId" in body["error"]


def test_error_ttl_zero(monkeypatch):
    # 目的: ttl=0 (不正) を指定した場合にバリデーションエラーとなることを確認
    # 期待値: status_code == 400, 'ttl' を含むエラー
    monkeypatch.setenv("SIGNING_SECRET", "secret")
    req = DummyReq({"ticketId": "t1", "deviceId": "d1", "ttl": 0})
    resp = issue.main(req)
    body = parse_body(resp)
    assert resp.status_code == 400
    assert "ttl" in body["error"]


def test_error_ttl_too_large(monkeypatch):
    # 目的: 許容上限 (600) を超える ttl=601 がバリデーションエラーになることを確認
    # 期待値: status_code == 400, 'ttl' を含むエラー
    monkeypatch.setenv("SIGNING_SECRET", "secret")
    req = DummyReq({"ticketId": "t1", "deviceId": "d1", "ttl": 601})
    resp = issue.main(req)
    body = parse_body(resp)
    assert resp.status_code == 400
    assert "ttl" in body["error"]


def test_error_missing_signing_secret(monkeypatch):
    # 目的: SIGNING_SECRET 未設定時にサーバー構成エラー (500) を返すことを確認
    # 期待値: status_code == 500, error == 'Server misconfiguration'
    # Ensure secret unset
    if "SIGNING_SECRET" in os.environ:
        monkeypatch.delenv("SIGNING_SECRET", raising=False)
    req = DummyReq({"ticketId": "t1", "deviceId": "d1"})
    resp = issue.main(req)
    body = parse_body(resp)
    assert resp.status_code == 500
    assert body["error"] == "Server misconfiguration"
