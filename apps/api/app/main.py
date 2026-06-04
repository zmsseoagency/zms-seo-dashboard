"""ZMS SEO Dashboard — FastAPI entrypoint."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import get_settings
from app.routers import health, clients

settings = get_settings()

app = FastAPI(
    title="ZMS SEO Dashboard API",
    version="0.1.0",
    docs_url="/docs",
    redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(clients.router)


@app.get("/")
def root():
    return {"service": "zms-api", "version": "0.1.0", "status": "ok"}
