# ZMS SEO Dashboard

Internal SEO automation platform for Zeal Media Solutions.

## Stack

- **Frontend**: Next.js 15 + TypeScript + Tailwind + shadcn/ui
- **Backend**: FastAPI + Celery + Redis
- **Database**: Supabase (Postgres + Auth + Storage + Vault)
- **Hosting**: Mac mini behind Cloudflare Tunnel
- **AI**: OpenRouter (default: anthropic/claude-sonnet-4.5)

## Structure

- `apps/web` — Next.js frontend
- `apps/api` — FastAPI backend + Celery workers
- `packages/shared` — Shared TypeScript types
- `infra/` — Docker Compose, Cloudflare config, Supabase migrations
- `docs/` — Internal documentation

## Setup

See [Setup Guide](./docs/setup.md).
