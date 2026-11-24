"""MCS4302 Week 8 lab: geofence event endpoints (under /w8).

Add to your main.py:
    from week8 import router as week8_router
    app.include_router(week8_router)
Or run alone:
    uvicorn week8:app --host 0.0.0.0 --port 8000

The phone sends only geofence events (enter / exit), never its location trace.
State is kept in memory; POST /w8/reset starts every run from empty.
"""
from __future__ import annotations

import threading
from datetime import datetime, timezone
from typing import Any, Callable, Dict, List, Literal

from fastapi import APIRouter, FastAPI, Request, Response
from fastapi.routing import APIRoute
from pydantic import BaseModel

# ---------------------------------------------------------------- byte counting
_STATS: Dict[str, Dict[str, int]] = {}


class CountingRoute(APIRoute):
    """Counts request and response BODY bytes per method + route (headers excluded)."""

    def get_route_handler(self) -> Callable:
        original = super().get_route_handler()
        path = self.path

        async def handler(request: Request) -> Response:
            body = await request.body()
            response = await original(request)
            key = f"{request.method} {path}"
            s = _STATS.setdefault(key, {"calls": 0, "req_bytes": 0, "resp_bytes": 0})
            s["calls"] += 1
            s["req_bytes"] += len(body)
            s["resp_bytes"] += len(getattr(response, "body", b"") or b"")
            return response

        return handler


router = APIRouter(prefix="/w8", tags=["week8"], route_class=CountingRoute)

# ---------------------------------------------------------------- server state
FENCE = {"id": "campus-gate", "lat": 6.9022, "lng": 79.8612, "radius_m": 100}

_lock = threading.Lock()
_events: List[Dict[str, Any]] = []
_by_key: Dict[str, Dict[str, Any]] = {}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


# ---------------------------------------------------------------- models
class EventIn(BaseModel):
    idem_key: str
    fence_id: str
    type: Literal["enter", "exit"]
    at: str  # device time of the event


# ---------------------------------------------------------------- endpoints
@router.post("/reset")
def reset():
    """Start a run: no events, byte counters at zero."""
    with _lock:
        _events.clear()
        _by_key.clear()
        _STATS.clear()
        return {"events": 0}


@router.get("/fence")
def fence():
    """The geofence the app uses (for reference)."""
    return FENCE


@router.post("/events")
def add_event(e: EventIn):
    """Store one geofence event. A repeated idem_key is stored only once."""
    with _lock:
        if e.idem_key in _by_key:
            return {"event": _by_key[e.idem_key], "duplicate": True}
        ev = {"id": len(_events) + 1, **(e.model_dump() if hasattr(e, "model_dump") else e.dict()), "received_at": _now()}
        _events.append(ev)
        _by_key[e.idem_key] = ev
        return {"event": ev, "duplicate": False}


@router.get("/events")
def list_events():
    """Every event stored since the last reset, oldest first."""
    with _lock:
        return {"events": list(_events)}


@router.get("/stats")
def stats():
    # Snapshot taken before this call is counted.
    return {"endpoints": {k: dict(v) for k, v in _STATS.items()}}


# Run this file on its own: uvicorn week8:app --host 0.0.0.0 --port 8000
app = FastAPI(title="MCS4302 Week 8")
app.include_router(router)
