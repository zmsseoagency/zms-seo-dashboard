"""JWT verification — validates Supabase-issued tokens."""
from typing import Annotated
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import jwt
from app.core.config import get_settings


bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> dict:
    """Verify the Supabase JWT and return the decoded claims."""
    if creds is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing token")

    settings = get_settings()
    try:
        payload = jwt.decode(
            creds.credentials,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid token: {exc}")

    return {
        "id": payload["sub"],
        "email": payload.get("email"),
        "role": payload.get("user_role", "member"),
        "jwt": creds.credentials,
    }


CurrentUser = Annotated[dict, Depends(get_current_user)]
