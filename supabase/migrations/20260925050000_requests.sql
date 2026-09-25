-- 건의함: 멤버가 앱 개선 요청을 올리고, Claude Code가 상태(status)와 처리 메모(claude_note)를 SQL로 갱신한다.
create table public.requests (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (length(trim(title)) > 0),
  body        text not null default '',
  kind        text not null default '기능 추가' check (kind in ('기능 추가','수정·버그','콘텐츠','디자인','기타')),
  status      text not null default 'new' check (status in ('new','reviewing','planned','in_progress','done','declined')),
  author      text not null default public.me(),
  claude_note text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.requests enable row level security;
create policy "read" on public.requests for select to authenticated using (public.is_member());
create policy "own insert" on public.requests for insert to authenticated
  with check (public.is_member() and author = public.me());
create policy "own update" on public.requests for update to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());
create policy "own delete" on public.requests for delete to authenticated
  using (public.is_member() and author = public.me());

-- 멤버는 제목·본문·종류만 쓸 수 있다. status, claude_note, author는 앱에서 바꿀 수 없다.
revoke insert, update on public.requests from anon, authenticated;
grant insert (title, body, kind) on public.requests to authenticated;
grant update (title, body, kind, updated_at) on public.requests to authenticated;

alter table public.comments  drop constraint comments_target_type_check;
alter table public.comments  add constraint comments_target_type_check  check (target_type in ('term','session','tagline','daily','drill','request'));
alter table public.favorites drop constraint favorites_target_type_check;
alter table public.favorites add constraint favorites_target_type_check check (target_type in ('term','session','tagline','daily','drill','request'));

alter publication supabase_realtime add table public.requests;
