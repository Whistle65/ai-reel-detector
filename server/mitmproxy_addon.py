"""mitmproxy addon: intercepts Instagram CDN video streams and triggers analysis."""

import asyncio
import json
import logging
import os
import re
import threading
from pathlib import Path
from urllib.parse import urlparse

import httpx
from mitmproxy import http

log = logging.getLogger(__name__)

# Load CDN domain config
_CONFIG_PATH = Path(__file__).parent / "config" / "domains.json"
with open(_CONFIG_PATH) as f:
    _CFG = json.load(f)

CDN_DOMAINS: set[str] = set(_CFG["cdn_domains"])
URL_PATTERNS: list[str] = _CFG["url_patterns"]
VIDEO_MIME: set[str] = set(_CFG["video_mime_types"])

ANALYZER_URL = os.environ.get("ANALYZER_URL", "http://127.0.0.1:8000/analyze")

# Maps X-Forwarded-For or client IP → device_id for push routing
_active_devices: dict[str, str] = {}


def _is_video_stream(flow: http.HTTPFlow) -> bool:
    host = flow.request.pretty_host
    if not any(domain in host for domain in CDN_DOMAINS):
        return False

    path = flow.request.path
    if any(p in path for p in URL_PATTERNS):
        return True

    content_type = flow.response.headers.get("content-type", "") if flow.response else ""
    return any(m in content_type for m in VIDEO_MIME)


def _extract_device_id(flow: http.HTTPFlow) -> str:
    return flow.client_conn.peername[0] if flow.client_conn.peername else "unknown"


class ReelDetectorAddon:
    def __init__(self):
        self._seen: set[str] = set()
        self._loop = asyncio.new_event_loop()
        t = threading.Thread(target=self._loop.run_forever, daemon=True)
        t.start()

    def response(self, flow: http.HTTPFlow):
        if not _is_video_stream(flow):
            return

        url = flow.request.url
        key = self._url_key(url)
        if key in self._seen:
            return
        self._seen.add(key)

        device_id = _extract_device_id(flow)
        log.info("Detected reel stream from %s: %s…", device_id, url[:80])

        asyncio.run_coroutine_threadsafe(
            self._trigger_analysis(url, device_id), self._loop
        )

    async def _trigger_analysis(self, url: str, device_id: str):
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.post(
                    ANALYZER_URL,
                    json={"video_url": url, "device_id": device_id},
                )
                if resp.status_code == 200:
                    result = resp.json()
                    log.info(
                        "Analysis complete device=%s confidence=%.3f is_ai=%s",
                        device_id, result["confidence"], result["is_ai"],
                    )
        except Exception as e:
            log.exception("Failed to trigger analysis: %s", e)

    @staticmethod
    def _url_key(url: str) -> str:
        parsed = urlparse(url)
        # Strip byte-range params so duplicate segment requests are deduplicated
        path = parsed.path
        return f"{parsed.netloc}{path}"


addons = [ReelDetectorAddon()]
