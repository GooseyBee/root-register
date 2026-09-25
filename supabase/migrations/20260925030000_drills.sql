-- 번역 연습: 한국어 문장을 각자 영어로 번역(블라인드), 모두 제출하면 추천 표현 공개.
-- 추천 표현은 Claude Code가 미리 써서 넣는다 (앱은 AI를 호출하지 않는다).

create table public.drills (
  id         text primary key default gen_random_uuid()::text,
  topic      text not null check (topic in ('marketing','business','daily','travel')),
  ko         text not null,
  context    text not null default '',
  sort       int  not null default 0,
  created_at timestamptz not null default now()
);

create table public.drill_answers (
  drill_id   text not null references public.drills(id) on delete cascade,
  author     text not null default public.me(),
  body       text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (drill_id, author)
);

create table public.drill_models (
  drill_id     text primary key references public.drills(id) on delete cascade,
  best         text not null,
  alternatives jsonb not null default '[]'::jsonb,  -- [text]
  notes        jsonb not null default '[]'::jsonb   -- [{phrase, why}]
);

-- 내가 이 문장에 제출했는가 (drill_answers 정책 안에서 같은 테이블을 다시 읽으면 재귀가 나서 definer 함수로 분리)
create or replace function public.drill_answered(d text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.drill_answers a where a.drill_id = d and a.author = public.me())
$$;

-- 멤버 모두가 제출했는가
create or replace function public.drill_revealed(d text) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.is_member() and not exists (
    select 1 from public.members m
    where not exists (select 1 from public.drill_answers a where a.drill_id = d and a.author = m.email)
  )
$$;

-- 누가 어떤 문장에 제출했는지 (본문 없이)
create or replace function public.drill_status() returns table (drill_id text, author text)
language sql stable security definer set search_path = '' as $$
  select a.drill_id, a.author from public.drill_answers a where public.is_member()
$$;

revoke execute on function public.drill_answered(text), public.drill_revealed(text), public.drill_status() from public, anon;
grant execute on function public.drill_answered(text), public.drill_revealed(text), public.drill_status() to authenticated;

alter table public.drills        enable row level security;
alter table public.drill_answers enable row level security;
alter table public.drill_models  enable row level security;

create policy "shared rw" on public.drills for all to authenticated
  using (public.is_member()) with check (public.is_member());

-- 블라인드: 내 답은 항상, 남의 답은 내가 제출한 문장에서만
create policy "blind read" on public.drill_answers for select to authenticated
  using (public.is_member() and (author = public.me() or public.drill_answered(drill_id)));
create policy "own insert" on public.drill_answers for insert to authenticated
  with check (public.is_member() and author = public.me());
create policy "own update" on public.drill_answers for update to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());
create policy "own delete" on public.drill_answers for delete to authenticated
  using (public.is_member() and author = public.me());

-- 추천 표현: 모두 제출한 뒤에만 읽기. 쓰기 정책 없음(관리자가 SQL로 넣는다)
create policy "revealed read" on public.drill_models for select to authenticated
  using (public.drill_revealed(drill_id));

-- 코멘트·즐겨찾기 대상에 drill 추가
alter table public.comments  drop constraint comments_target_type_check;
alter table public.comments  add constraint comments_target_type_check  check (target_type in ('term','session','tagline','daily','drill'));
alter table public.favorites drop constraint favorites_target_type_check;
alter table public.favorites add constraint favorites_target_type_check check (target_type in ('term','session','tagline','daily','drill'));

alter publication supabase_realtime add table public.drills, public.drill_answers;
