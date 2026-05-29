import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from analyzer import analyze_reel
from apns_sender import push_analyzing, push_result, push_error
from config import settings

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# In-memory store for active push tokens keyed by device_id
_push_tokens: dict[str, str] = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("ReelDetector server started")
    yield
    log.info("ReelDetector server stopped")


app = FastAPI(title="ReelDetector API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class RegisterRequest(BaseModel):
    device_id: str
    push_token: str


class AnalyzeRequest(BaseModel):
    video_url: str
    device_id: str


class AnalyzeResponse(BaseModel):
    confidence: float
    is_ai: bool
    frame_count: int


@app.post("/register")
async def register_device(req: RegisterRequest):
    """Store the Live Activity push token for a device."""
    _push_tokens[req.device_id] = req.push_token
    log.info("Registered device %s", req.device_id)
    return {"ok": True}


@app.post("/analyze", response_model=AnalyzeResponse)
async def analyze(req: AnalyzeRequest, background_tasks: BackgroundTasks):
    """Analyze a reel URL and return AI confidence score.

    Also pushes Live Activity updates via APNs if device is registered.
    """
    push_token = _push_tokens.get(req.device_id)

    if push_token:
        background_tasks.add_task(push_analyzing, push_token)

    try:
        result = await analyze_reel(req.video_url)
        log.info(
            "device=%s url=%s confidence=%.3f is_ai=%s",
            req.device_id, req.video_url[:60],
            result["confidence"], result["is_ai"],
        )

        if push_token:
            background_tasks.add_task(
                push_result, push_token, result["confidence"], result["is_ai"]
            )

        return AnalyzeResponse(
            confidence=result["confidence"],
            is_ai=result["is_ai"],
            frame_count=result["frame_count"],
        )

    except ValueError as e:
        if push_token:
            background_tasks.add_task(push_error, push_token)
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        log.exception("Analysis failed: %s", e)
        if push_token:
            background_tasks.add_task(push_error, push_token)
        raise HTTPException(status_code=500, detail="Analysis failed")


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.server_host,
        port=settings.server_port,
        workers=1,
    )
