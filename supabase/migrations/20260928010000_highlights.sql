-- 하이라이트 메모 (혜림 님 건의, 2026-09-28): 번역 연습·교차번역 문장에서 단어·숙어를 골라 메모를 단다.
-- 개인 공부 노트라서 본인만 읽고 쓴다(오답 노트처럼). 모아 보기 화면에서 전부 다시 볼 수 있다.
create table public.highlights (
  id          uuid primary key default gen_random_uuid(),
  author      text not null default public.me(),
  target_type text not null check (target_type in ('drill', 'session')),
  target_id   text not null,
  quote       text not null check (length(quote) between 1 and 200),  -- 고른 단어·숙어
  note        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index highlights_author_target on public.highlights (author, target_type, target_id);
alter table public.highlights enable row level security;
create policy "own" on public.highlights for all to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());
alter publication supabase_realtime add table public.highlights;
