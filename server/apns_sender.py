import time
from pathlib import Path

import httpx
import jwt

from config import settings


def _make_jwt() -> str:
    private_key = Path(settings.apns_private_key_path).read_text()
    payload = {"iss": settings.apns_team_id, "iat": int(time.time())}
    return jwt.encode(
        payload,
        private_key,
        algorithm="ES256",
        headers={"kid": settings.apns_key_id},
    )


def _apns_host() -> str:
    if settings.apns_sandbox:
        return "https://api.sandbox.push.apple.com"
    return "https://api.push.apple.com"


async def push_live_activity_update(
    push_token: str,
    status: str,
    confidence: float,
    is_ai: bool,
) -> bool:
    """Push a Live Activity content-state update to the Dynamic Island."""
    now = int(time.time())
    payload = {
        "aps": {
            "timestamp": now,
            "event": "update",
            "content-state": {
                "status": status,
                "aiConfidence": confidence,
                "isAI": is_ai,
                "updatedAt": now,
            },
        }
    }

    headers = {
        "authorization": f"bearer {_make_jwt()}",
        "apns-push-type": "liveactivity",
        "apns-topic": f"{settings.apns_bundle_id}.push-type.liveactivity",
        "apns-priority": "10",
        "content-type": "application/json",
    }

    url = f"{_apns_host()}/3/device/{push_token}"

    async with httpx.AsyncClient(http2=True, timeout=10) as client:
        resp = await client.post(url, json=payload, headers=headers)
        return resp.status_code == 200


async def push_analyzing(push_token: str) -> bool:
    return await push_live_activity_update(
        push_token, status="analyzing", confidence=0.0, is_ai=False
    )


async def push_result(push_token: str, confidence: float, is_ai: bool) -> bool:
    return await push_live_activity_update(
        push_token, status="result", confidence=confidence, is_ai=is_ai
    )


async def push_error(push_token: str) -> bool:
    return await push_live_activity_update(
        push_token, status="error", confidence=0.0, is_ai=False
    )
