"""Client management endpoints."""
from fastapi import APIRouter
from app.core.security import CurrentUser
from app.core.supabase_client import get_user_client

router = APIRouter(prefix="/clients", tags=["clients"])


@router.get("")
def list_clients(user: CurrentUser):
    """List clients the current user can access (RLS-enforced)."""
    sb = get_user_client(user["jwt"])
    result = sb.table("clients").select("*").order("name").execute()
    return {"clients": result.data}
