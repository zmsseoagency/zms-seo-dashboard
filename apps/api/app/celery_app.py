"""Celery application configured for ZMS background jobs."""
from celery import Celery
from app.core.config import get_settings

settings = get_settings()

celery = Celery(
    "zms",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
    include=[
        # task modules will be added here as we build them
        # "app.tasks.indexing",
        # "app.tasks.keyword_research",
        # "app.tasks.blog_generation",
    ],
)

celery.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="America/Los_Angeles",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    result_expires=86400 * 7,
)
