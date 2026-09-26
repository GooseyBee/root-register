-- 코멘트 좋아요 (2026-09-26). 코멘트·답장마다 1인 1회.
create table public.comment_likes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  author     text not null default public.me(),
  created_at timestamptz not null default now(),
  primary key (comment_id, author)
);
alter table public.comment_likes enable row level security;
-- 누가 좋아했는지는 멤버끼리 본다. 코멘트 본문이 없으니, 볼 수 없는 코멘트(번역 연습 블라인드)의 내용은 새지 않는다.
create policy "read" on public.comment_likes for select to authenticated using (public.is_member());
create policy "own insert" on public.comment_likes for insert to authenticated with check (public.is_member() and author = public.me());
create policy "own delete" on public.comment_likes for delete to authenticated using (public.is_member() and author = public.me());
alter publication supabase_realtime add table public.comment_likes;
