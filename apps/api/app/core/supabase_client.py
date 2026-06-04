"""Supabase client singletons for service-role and per-request user contexts."""
from functools import lru_cache
from supabase import create_client, Client
from app.core.config import get_settings


@lru_cache
def get_service_client() -> Client:
    """Service-role client — bypasses RLS. Use for backend-internal operations."""
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_service_role_key)


def get_user_client(jwt: str) -> Client:
    """Per-request client authed as the current user — RLS applies."""
    settings = get_settings()
    client = create_client(settings.supabase_url, settings.supabase_anon_key)
    client.auth.set_session(jwt, jwt)
    return client
