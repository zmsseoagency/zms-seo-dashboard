"""Health check endpoints."""
from fastapi import APIRouter
from app.core.supabase_client import get_service_client

router = APIRouter(prefix="/health", tags=["health"])


@router.get("")
def health():
    return {"status": "ok"}


@router.get("/db")
def health_db():
    try:
        client = get_service_client()
        client.table("user_profiles").select("id", count="exact").limit(1).execute()
        return {"status": "ok", "db": "connected"}
    except Exception as exc:
        return {"status": "error", "db": str(exc)}
