-- Root & Register: 초기 스키마
-- 로그인 이메일이 members 에 있는 사람만 읽고 쓸 수 있다.

create table public.members (
  email        text primary key check (email = lower(email)),
  display_name text not null
);

create or replace function public.me() returns text
language sql stable as $$ select lower(auth.jwt() ->> 'email') $$;

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.members where email = public.me())
$$;

create table public.roots (
  id         text primary key default gen_random_uuid()::text,
  en         jsonb not null,            -- {root, meaning, words[]}
  ko         jsonb not null,            -- {hanja, hun, words[]}
  session    int,
  note       text not null default '',
  added_by   text default public.me(),
  created_at timestamptz not null default now()
);

create table public.terms (
  id         text primary key default gen_random_uuid()::text,
  word       text not null,
  pair       text not null default '',
  meaning    text not null,
  examples   jsonb not null default '[]'::jsonb,  -- [{s, t}]
  register   text not null default '문어' check (register in ('구어','문어','전문')),
  domain     text not null default '일반',
  root_id    text references public.roots(id) on delete set null,
  lang       text not null check (lang in ('ko','en')),
  added_by   text default public.me(),
  created_at timestamptz not null default now()
);

create table public.sessions (
  id         text primary key default gen_random_uuid()::text,
  no         int not null,
  date       date,
  dir        text not null check (dir in ('KR→EN','EN→KR')),
  title      text not null,
  source     text not null,
  final      text not null default '',
  notes      text not null default '',
  created_at timestamptz not null default now()
);

create table public.session_versions (
  session_id text not null references public.sessions(id) on delete cascade,
  author     text not null default public.me(),
  body       text not null default '',
  updated_at timestamptz not null default now(),
  primary key (session_id, author)
);

create table public.taglines (
  id         text primary key default gen_random_uuid()::text,
  text       text not null,
  brief      text not null default '',
  added_by   text default public.me(),
  created_at timestamptz not null default now()
);

create table public.tagline_comments (
  id         uuid primary key default gen_random_uuid(),
  tagline_id text not null references public.taglines(id) on delete cascade,
  author     text not null default public.me(),
  body       text not null,
  created_at timestamptz not null default now()
);

-- 복습 진도는 사람마다 따로
create table public.reviews (
  author  text not null default public.me(),
  term_id text not null references public.terms(id) on delete cascade,
  box     int  not null check (box between 1 and 5),
  due     date not null,
  last    date,
  primary key (author, term_id)
);

-- RLS
alter table public.members          enable row level security;
alter table public.roots            enable row level security;
alter table public.terms            enable row level security;
alter table public.sessions         enable row level security;
alter table public.session_versions enable row level security;
alter table public.taglines         enable row level security;
alter table public.tagline_comments enable row level security;
alter table public.reviews          enable row level security;

create policy "members read" on public.members for select to authenticated using (public.is_member());

create policy "shared rw" on public.roots    for all to authenticated using (public.is_member()) with check (public.is_member());
create policy "shared rw" on public.terms    for all to authenticated using (public.is_member()) with check (public.is_member());
create policy "shared rw" on public.sessions for all to authenticated using (public.is_member()) with check (public.is_member());
create policy "shared rw" on public.taglines for all to authenticated using (public.is_member()) with check (public.is_member());

create policy "read" on public.session_versions for select to authenticated using (public.is_member());
create policy "own write" on public.session_versions for all to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());

create policy "read" on public.tagline_comments for select to authenticated using (public.is_member());
create policy "own write" on public.tagline_comments for all to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());

create policy "own only" on public.reviews for all to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());

-- 실시간 반영
alter publication supabase_realtime add table
  public.roots, public.terms, public.sessions, public.session_versions,
  public.taglines, public.tagline_comments, public.reviews;
