-- 코멘트·즐겨찾기 일반화, 오늘의 문장, 어근 짝 삭제
-- 오늘의 문장은 AI를 호출하지 않는다: 설명(note)과 어려운 단어(words)는 terms.examples 안에 미리 저장해 둔 값을 복사한다.

-- 1) 범용 코멘트 (용어, 세션, 태그라인, 오늘의 문장)
create table public.comments (
  id          uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('term','session','tagline','daily')),
  target_id   text not null,
  author      text not null default public.me(),
  body        text not null,
  created_at  timestamptz not null default now()
);
create index comments_target on public.comments (target_type, target_id);

insert into public.comments (target_type, target_id, author, body, created_at)
  select 'tagline', tagline_id, author, body, created_at from public.tagline_comments;
drop table public.tagline_comments;

alter table public.comments enable row level security;
create policy "read" on public.comments for select to authenticated using (public.is_member());
create policy "own write" on public.comments for all to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());

-- 2) 즐겨찾기 (사람마다 따로)
create table public.favorites (
  author      text not null default public.me(),
  target_type text not null check (target_type in ('term','session','tagline','daily')),
  target_id   text not null,
  created_at  timestamptz not null default now(),
  primary key (author, target_type, target_id)
);
alter table public.favorites enable row level security;
create policy "own only" on public.favorites for all to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());

-- 3) 오늘의 문장 (하루 1개, 두 사람 공유)
create table public.daily_sentences (
  day         date primary key,
  term_id     text references public.terms(id) on delete set null,
  sentence    text not null,
  translation text not null default '',
  explanation text not null default '',
  words       jsonb not null default '[]'::jsonb,   -- [{word, meaning, note}]
  created_at  timestamptz not null default now()
);
alter table public.daily_sentences enable row level security;
create policy "shared rw" on public.daily_sentences for all to authenticated
  using (public.is_member()) with check (public.is_member());

-- 오늘(서울) 문장을 돌려준다. 없으면 용어집 영어 예문(설명이 있는 것 우선)에서 최근 30일에 안 쓴 것을 골라 만든다.
create or replace function public.ensure_daily() returns public.daily_sentences
language plpgsql security invoker set search_path = '' as $$
declare
  d date := (now() at time zone 'Asia/Seoul')::date;
  r public.daily_sentences;
begin
  if not public.is_member() then raise exception 'not a member'; end if;
  select * into r from public.daily_sentences where day = d;
  if found then return r; end if;

  insert into public.daily_sentences (day, term_id, sentence, translation, explanation, words)
  select d, t.id, e->>'s', coalesce(e->>'t', ''), coalesce(e->>'note', ''), coalesce(e->'words', '[]'::jsonb)
  from public.terms t, jsonb_array_elements(t.examples) e
  where t.lang = 'en' and coalesce(e->>'s', '') <> ''
    and not exists (select 1 from public.daily_sentences x where x.sentence = e->>'s' and x.day > d - 30)
  order by (coalesce(e->>'note', '') = ''), random() limit 1
  on conflict (day) do nothing;

  if not found then  -- 모두 최근에 썼으면 제한 없이 고른다
    insert into public.daily_sentences (day, term_id, sentence, translation, explanation, words)
    select d, t.id, e->>'s', coalesce(e->>'t', ''), coalesce(e->>'note', ''), coalesce(e->'words', '[]'::jsonb)
    from public.terms t, jsonb_array_elements(t.examples) e
    where t.lang = 'en' and coalesce(e->>'s', '') <> ''
    order by random() limit 1
    on conflict (day) do nothing;
  end if;

  select * into r from public.daily_sentences where day = d;
  return r;
end $$;
revoke execute on function public.ensure_daily() from public, anon;
grant execute on function public.ensure_daily() to authenticated;

-- 4) 어근 짝 삭제
alter table public.terms drop column root_id;
drop table public.roots;

-- 5) 실시간 반영
alter publication supabase_realtime add table public.comments, public.favorites, public.daily_sentences;
