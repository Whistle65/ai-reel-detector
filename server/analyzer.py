import asyncio
import json
import os
import random
import tempfile
from pathlib import Path

import httpx
import yt_dlp

from config import settings

HIVE_ENDPOINT = "https://api.thehive.ai/api/v2/task/sync"

# Set to True once you have a Hive API key and want real classification.
_HIVE_ENABLED = False

# Load CDN domains from the same config mitmproxy_addon uses
_DOMAINS_CFG_PATH = Path(__file__).parent / "config" / "domains.json"
with open(_DOMAINS_CFG_PATH) as _f:
    _DOMAINS_CFG = json.load(_f)
_CDN_URL_DOMAINS: list[str] = _DOMAINS_CFG["cdn_domains"]
_VIDEO_EXTENSIONS: tuple[str, ...] = tuple(_DOMAINS_CFG.get("video_extensions", [".mp4", ".m4v", ".mov"]))


async def analyze_reel(video_url: str) -> dict:
    with tempfile.TemporaryDirectory() as tmpdir:
        video_path = await _download(video_url, Path(tmpdir))
        frames = await _extract_keyframes(video_path, Path(tmpdir))
        scores = await _classify_parallel(frames)

    avg = sum(scores) / len(scores) if scores else 0.0
    return {
        "confidence": round(avg, 4),
        "frame_count": len(scores),
        "frame_scores": [round(s, 4) for s in scores],
        "is_ai": avg >= 0.5,
    }


async def _download(url: str, tmpdir: Path) -> Path:
    output_path = tmpdir / "reel.mp4"

    # Try direct CDN download first (faster for mitmproxy-captured URLs)
    if _is_cdn_url(url):
        await _download_direct(url, output_path)
        return output_path

    # Fall back to yt-dlp for Instagram page URLs
    await asyncio.to_thread(_ytdlp_download, url, str(output_path))
    return output_path


_COOKIES_PATH = str(Path(__file__).parent / "cookies.txt")


def _ytdlp_download(url: str, output_path: str):
    ydl_opts = {
        "outtmpl": output_path,
        "format": "mp4[filesize<50M]/best[filesize<50M]/mp4/best",
        "quiet": True,
        "no_warnings": True,
        "max_filesize": settings.max_video_mb * 1024 * 1024,
        "cookiefile": _COOKIES_PATH,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])


async def _download_direct(url: str, output_path: Path):
    max_bytes = settings.max_video_mb * 1024 * 1024
    async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
        async with client.stream("GET", url) as resp:
            resp.raise_for_status()
            received = 0
            with open(output_path, "wb") as f:
                async for chunk in resp.aiter_bytes(65536):
                    received += len(chunk)
                    if received > max_bytes:
                        raise ValueError(f"Video exceeds {settings.max_video_mb} MB cap")
                    f.write(chunk)


async def _extract_keyframes(video_path: Path, tmpdir: Path) -> list[Path]:
    frames_dir = tmpdir / "frames"
    frames_dir.mkdir()
    duration = await asyncio.to_thread(_probe_duration_sync, video_path)
    fps = settings.hive_frame_count / max(duration, 1)
    await asyncio.to_thread(_ffmpeg_extract, video_path, frames_dir, fps)
    return sorted(frames_dir.glob("frame_*.jpg"))


def _probe_duration_sync(path: Path) -> float:
    import subprocess as sp
    result = sp.run(
        ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", str(path)],
        capture_output=True, text=True,
    )
    try:
        info = json.loads(result.stdout)
        return float(info.get("format", {}).get("duration", 30))
    except (json.JSONDecodeError, ValueError):
        return 30.0


def _ffmpeg_extract(video_path: Path, frames_dir: Path, fps: float):
    import subprocess as sp
    sp.run([
        "ffmpeg", "-i", str(video_path),
        "-vf", f"fps={fps:.6f}",
        "-frames:v", str(settings.hive_frame_count),
        "-q:v", "3",
        "-f", "image2",
        str(frames_dir / "frame_%03d.jpg"),
        "-y",
    ], capture_output=True)


async def _classify_parallel(frames: list[Path]) -> list[float]:
    if not _HIVE_ENABLED:
        # Stub: returns a random score so the full pipeline can be tested
        # end-to-end (VPN → mitmproxy → download → APNs → Dynamic Island)
        # without a Hive key. Swap _HIVE_ENABLED = True when ready.
        await asyncio.sleep(0.5)  # simulate network latency
        return [random.uniform(0.1, 0.9) for _ in frames]

    async with httpx.AsyncClient(
        timeout=30,
        headers={"Authorization": f"Token {settings.hive_api_key}"},
    ) as client:
        tasks = [_classify_frame(f, client) for f in frames]
        return await asyncio.gather(*tasks)


async def _classify_frame(frame: Path, client: httpx.AsyncClient) -> float:
    with open(frame, "rb") as f:
        resp = await client.post(
            HIVE_ENDPOINT,
            files={"image": (frame.name, f, "image/jpeg")},
            data={"model": "ai_generated_image_detection"},
        )
    resp.raise_for_status()
    data = resp.json()

    try:
        classes = (
            data["status"][0]["response"]["output"][0]["classes"]
        )
        for cls in classes:
            if cls["class"] == "ai_generated":
                return float(cls["score"])
    except (KeyError, IndexError):
        pass
    return 0.0


def _is_cdn_url(url: str) -> bool:
    if any(d in url for d in _CDN_URL_DOMAINS):
        return True
    from urllib.parse import urlparse
    path = urlparse(url).path.lower()
    return path.endswith(_VIDEO_EXTENSIONS)
