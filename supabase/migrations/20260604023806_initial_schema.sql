-- ============================================================================
-- ZMS SEO Dashboard — Initial Schema
-- ============================================================================

-- Enable required extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";

-- ============================================================================
-- ENUMS
-- ============================================================================

create type user_role as enum ('admin', 'member');
create type client_status as enum ('onboarding', 'active', 'paused', 'archived');
create type cms_type as enum ('wordpress', 'ghl', 'other');
create type blog_status as enum ('draft', 'pending_review', 'approved', 'published', 'archived');
create type audit_type as enum ('onpage', 'technical', 'local');
create type indexing_status as enum ('pending', 'submitted', 'indexed', 'failed', 'expired');
create type indexing_source as enum ('manual', 'auto_detected', 'bulk_csv');
create type job_status as enum ('queued', 'running', 'success', 'failed', 'retrying');

-- ============================================================================
-- USERS (extends Supabase auth.users)
-- ============================================================================

create table public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text,
  role user_role not null default 'member',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- CLIENTS
-- ============================================================================

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  website text,
  business_address text,
  phone text,
  gbp_url text,
  gbp_place_id text,
  cms cms_type,
  industry text,
  service_areas jsonb default '[]'::jsonb,
  brand_voice text,
  notes text,
  status client_status not null default 'onboarding',
  baseline_completed boolean not null default false,
  baseline_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.user_profiles(id)
);

create index idx_clients_slug on public.clients(slug);
create index idx_clients_status on public.clients(status);

-- ============================================================================
-- CLIENT ASSIGNMENTS (many-to-many users <-> clients)
-- ============================================================================

create table public.client_assignments (
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  assigned_by uuid references public.user_profiles(id),
  primary key (user_id, client_id)
);

create index idx_assignments_client on public.client_assignments(client_id);

-- ============================================================================
-- CLIENT CREDENTIALS (encrypted via Supabase Vault)
-- ============================================================================

create table public.client_credentials (
  client_id uuid primary key references public.clients(id) on delete cascade,
  gsc_property text,
  ga4_property_id text,
  wp_url text,
  wp_username text,
  wp_app_password_vault_id uuid,
  ghl_location_id text,
  ghl_api_key_vault_id uuid,
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- COMPETITORS
-- ============================================================================

create table public.client_competitors (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  competitor_url text not null,
  label text,
  notes text,
  added_at timestamptz not null default now()
);

create index idx_competitors_client on public.client_competitors(client_id);

-- ============================================================================
-- KEYWORDS
-- ============================================================================

create table public.client_keywords (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  keyword text not null,
  intent text,
  cluster text,
  target_url text,
  search_volume integer,
  difficulty integer,
  baseline_rank integer,
  current_rank integer,
  is_tracking boolean not null default true,
  last_checked_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_keywords_client on public.client_keywords(client_id);
create index idx_keywords_cluster on public.client_keywords(client_id, cluster);

-- ============================================================================
-- RANK HISTORY (time-series)
-- ============================================================================

create table public.rank_history (
  id bigserial primary key,
  keyword_id uuid not null references public.client_keywords(id) on delete cascade,
  rank integer,
  url text,
  checked_at timestamptz not null default now()
);

create index idx_rank_history_keyword_date on public.rank_history(keyword_id, checked_at desc);

-- ============================================================================
-- AUDITS
-- ============================================================================

create table public.audits (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  audit_type audit_type not null,
  url text,
  score numeric(5,2),
  issues jsonb default '[]'::jsonb,
  recommendations jsonb default '[]'::jsonb,
  raw_data jsonb default '{}'::jsonb,
  run_at timestamptz not null default now(),
  run_by uuid references public.user_profiles(id)
);

create index idx_audits_client on public.audits(client_id, run_at desc);

-- ============================================================================
-- BLOGS
-- ============================================================================

create table public.blogs (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  title text not null,
  slug text,
  target_keyword text,
  brief jsonb default '{}'::jsonb,
  content_md text,
  content_html text,
  meta_title text,
  meta_description text,
  status blog_status not null default 'draft',
  scheduled_for date,
  published_at timestamptz,
  published_url text,
  word_count integer,
  regeneration_count integer not null default 0,
  created_by_bot boolean not null default true,
  reviewed_by uuid references public.user_profiles(id),
  published_by uuid references public.user_profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_blogs_client_status on public.blogs(client_id, status);
create index idx_blogs_scheduled on public.blogs(scheduled_for) where status in ('pending_review', 'approved');

-- ============================================================================
-- BLOG REVISIONS (audit trail of edits)
-- ============================================================================

create table public.blog_revisions (
  id bigserial primary key,
  blog_id uuid not null references public.blogs(id) on delete cascade,
  content_md text,
  edited_by uuid references public.user_profiles(id),
  edit_summary text,
  edited_at timestamptz not null default now()
);

create index idx_revisions_blog on public.blog_revisions(blog_id, edited_at desc);

-- ============================================================================
-- REPORTS
-- ============================================================================

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  data jsonb not null default '{}'::jsonb,
  pdf_storage_path text,
  generated_at timestamptz not null default now(),
  generated_by uuid references public.user_profiles(id)
);

create index idx_reports_client on public.reports(client_id, period_start desc);

-- ============================================================================
-- GSC DATA (daily rollups)
-- ============================================================================

create table public.gsc_daily (
  id bigserial primary key,
  client_id uuid not null references public.clients(id) on delete cascade,
  date date not null,
  query text,
  page text,
  clicks integer not null default 0,
  impressions integer not null default 0,
  ctr numeric(6,4),
  position numeric(6,2)
);

create index idx_gsc_client_date on public.gsc_daily(client_id, date desc);
create unique index uq_gsc_daily on public.gsc_daily(client_id, date, query, page);

-- ============================================================================
-- GA4 DATA (daily rollups)
-- ============================================================================

create table public.ga4_daily (
  id bigserial primary key,
  client_id uuid not null references public.clients(id) on delete cascade,
  date date not null,
  source text,
  medium text,
  sessions integer not null default 0,
  users integer not null default 0,
  conversions integer not null default 0
);

create index idx_ga4_client_date on public.ga4_daily(client_id, date desc);

-- ============================================================================
-- INDEXING — GCP project pool
-- ============================================================================

create table public.indexing_gcp_projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client_email text not null,
  credentials_vault_id uuid not null,
  daily_quota integer not null default 200,
  quota_used_today integer not null default 0,
  quota_reset_at timestamptz not null default now(),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- INDEXING — URL queue
-- ============================================================================

create table public.indexing_queue (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  url text not null,
  source indexing_source not null default 'manual',
  status indexing_status not null default 'pending',
  gcp_project_id uuid references public.indexing_gcp_projects(id),
  submitted_at timestamptz,
  indexed_at timestamptz,
  last_checked_at timestamptz,
  error_message text,
  created_at timestamptz not null default now()
);

create index idx_indexing_client_status on public.indexing_queue(client_id, status);
create index idx_indexing_pending on public.indexing_queue(status) where status = 'pending';

-- ============================================================================
-- GBP DATA
-- ============================================================================

create table public.gbp_data (
  client_id uuid primary key references public.clients(id) on delete cascade,
  posts jsonb default '[]'::jsonb,
  reviews jsonb default '[]'::jsonb,
  qna jsonb default '[]'::jsonb,
  insights jsonb default '{}'::jsonb,
  synced_at timestamptz not null default now()
);

-- ============================================================================
-- JOBS (Celery task log)
-- ============================================================================

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  client_id uuid references public.clients(id) on delete cascade,
  status job_status not null default 'queued',
  payload jsonb default '{}'::jsonb,
  result jsonb,
  error text,
  retry_count integer not null default 0,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_jobs_client on public.jobs(client_id, created_at desc);
create index idx_jobs_status on public.jobs(status) where status in ('queued', 'running');

-- ============================================================================
-- AUDIT LOG (user actions)
-- ============================================================================

create table public.audit_log (
  id bigserial primary key,
  user_id uuid references public.user_profiles(id),
  action text not null,
  entity_type text,
  entity_id uuid,
  changes jsonb,
  created_at timestamptz not null default now()
);

create index idx_audit_log_entity on public.audit_log(entity_type, entity_id);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

create or replace function public.is_admin(uid uuid) returns boolean
language sql stable security definer as $$
  select exists (
    select 1 from public.user_profiles
    where id = uid and role = 'admin' and is_active = true
  );
$$;

create or replace function public.user_can_access_client(uid uuid, cid uuid) returns boolean
language sql stable security definer as $$
  select public.is_admin(uid) or exists (
    select 1 from public.client_assignments
    where user_id = uid and client_id = cid
  );
$$;

-- ============================================================================
-- TRIGGERS — updated_at
-- ============================================================================

create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_user_profiles_updated before update on public.user_profiles
  for each row execute function public.set_updated_at();
create trigger trg_clients_updated before update on public.clients
  for each row execute function public.set_updated_at();
create trigger trg_blogs_updated before update on public.blogs
  for each row execute function public.set_updated_at();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

alter table public.user_profiles enable row level security;
alter table public.clients enable row level security;
alter table public.client_assignments enable row level security;
alter table public.client_credentials enable row level security;
alter table public.client_competitors enable row level security;
alter table public.client_keywords enable row level security;
alter table public.rank_history enable row level security;
alter table public.audits enable row level security;
alter table public.blogs enable row level security;
alter table public.blog_revisions enable row level security;
alter table public.reports enable row level security;
alter table public.gsc_daily enable row level security;
alter table public.ga4_daily enable row level security;
alter table public.indexing_queue enable row level security;
alter table public.gbp_data enable row level security;
alter table public.jobs enable row level security;
alter table public.audit_log enable row level security;

-- User profiles
create policy "profiles_select" on public.user_profiles for select to authenticated using (true);
create policy "profiles_update_self" on public.user_profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Clients
create policy "clients_select" on public.clients for select to authenticated
  using (public.user_can_access_client(auth.uid(), id));
create policy "clients_insert_admin" on public.clients for insert to authenticated
  with check (public.is_admin(auth.uid()));
create policy "clients_update_admin" on public.clients for update to authenticated
  using (public.is_admin(auth.uid()));
create policy "clients_delete_admin" on public.clients for delete to authenticated
  using (public.is_admin(auth.uid()));

-- Assignments
create policy "assignments_select" on public.client_assignments for select to authenticated
  using (user_id = auth.uid() or public.is_admin(auth.uid()));
create policy "assignments_all_admin" on public.client_assignments for all to authenticated
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

-- Credentials
create policy "creds_select" on public.client_credentials for select to authenticated
  using (public.user_can_access_client(auth.uid(), client_id));
create policy "creds_modify_admin" on public.client_credentials for all to authenticated
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

create policy "competitors_all" on public.client_competitors for all to authenticated
  using (public.user_can_access_client(auth.uid(), client_id))
  with check (public.user_can_access_client(auth.uid(), client_id));

create policy "keywords_all" on public.client_keywords for all to authenticated
  using (public.user_can_access_client(auth.uid(), client_id))
  with check (public.user_can_access_client(auth.uid(), client_id));

create policy "rank_history_select" on public.rank_history for select to authenticated
  using (exists (
    select 1 from public.client_keywords k
    where k.id = rank_history.keyword_id
      and public.user_can_access_client(auth.uid(), k.client_id)
  ));

create policy "audits_all" on public.audits for all to authenticated
  using (public.user_can_access_client(auth.uid(), client_id))
  with check (public.user_can_access_client(auth.uid(), client_id));

create policy "blogs_all" on public.blogs for all to authenticated
  using (public.user_can_access_client(auth.uid(), client_id))
  with check (public.user_can_access_client(auth.uid(), client_id));

create policy "revisions_select" on public.blog_revisions for select to authenticated
  using (exists (
    select 1 from public.blogs b
    where b.id = blog_revisions.blog_id
      and public.user_can_access_client(auth.uid(), b.client_id)
  ));

create policy "reports_select" on public.reports for select to authenticated
  using (public.user_can_access_client(auth.uid(), client_id));
create policy "reports_modify_admin" on public.reports for all to authenticated
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

create policy "gsc_select" on public.gsc_daily for select to authenticated
  using (public.user_can_access_client(auth.uid(), client_id));

create policy "ga4_select" on public.ga4_daily for select to authenticated
  using (public.user_can_access_client(auth.uid(), client_id));

create policy "indexing_all" on public.indexing_queue for all to authenticated
  using (public.user_can_access_client(auth.uid(), client_id))
  with check (public.user_can_access_client(auth.uid(), client_id));

create policy "gbp_select" on public.gbp_data for select to authenticated
  using (public.user_can_access_client(auth.uid(), client_id));

create policy "jobs_select" on public.jobs for select to authenticated
  using (client_id is null and public.is_admin(auth.uid())
         or public.user_can_access_client(auth.uid(), client_id));

create policy "audit_log_admin" on public.audit_log for select to authenticated
  using (public.is_admin(auth.uid()));

-- ============================================================================
-- AUTO-CREATE user_profiles when auth.users is created
-- ============================================================================

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer as $$
begin
  insert into public.user_profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    'member'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
