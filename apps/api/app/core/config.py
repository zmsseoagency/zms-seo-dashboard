"""Application configuration loaded from environment variables."""
from functools import lru_cache
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Environment
    environment: str = Field(default="development")

    # Supabase
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    supabase_jwt_secret: str

    # Redis / Celery
    redis_url: str = Field(default="redis://redis:6379/0")
    celery_broker_url: str = Field(default="redis://redis:6379/1")
    celery_result_backend: str = Field(default="redis://redis:6379/2")

    # OpenRouter
    openrouter_api_key: str
    openrouter_default_model: str = Field(default="anthropic/claude-sonnet-4.5")
    openrouter_cheap_model: str = Field(default="anthropic/claude-haiku-4.5")
    openrouter_site_url: str = Field(default="https://dashboard.zealmediasolutions.com")
    openrouter_app_name: str = Field(default="ZMS SEO Dashboard")

    # DataForSEO
    dataforseo_login: str
    dataforseo_password: str

    # Google
    google_pagespeed_api_key: str = ""

    # App
    cors_origins: list[str] = Field(default_factory=lambda: ["https://dashboard.zealmediasolutions.com", "http://localhost:3000"])
    log_level: str = Field(default="INFO")


@lru_cache
def get_settings() -> Settings:
    return Settings()
