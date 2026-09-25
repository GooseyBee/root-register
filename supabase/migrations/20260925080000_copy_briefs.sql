-- 영어 카피 연습(구 태그라인 보드): 주마다 Claude가 브리프를 넣고, 멤버는 브리프별로 영어 카피를 블라인드 제출한다.
create table public.copy_briefs (
  id         text primary key,
  week       date not null,            -- 그 주 월요일
  title      text not null,            -- 브리프 이름 (제품·브랜드)
  product    text not null default '', -- 무엇을 알리나
  target     text not null default '', -- 누구에게
  tone       text not null default '', -- 어떤 톤으로
  rules      text not null default '', -- 조건 (길이, 꼭 넣을 것, 피할 것)
  sort       int  not null default 0,
  created_at timestamptz not null default now()
);
alter table public.copy_briefs enable row level security;
create policy "read" on public.copy_briefs for select to authenticated using (public.is_member());
-- 쓰기 정책 없음: 브리프는 Claude가 SQL로 넣는다.

alter table public.taglines add column brief_id text references public.copy_briefs(id) on delete set null;

-- 내가 이 브리프에 카피를 냈는가 (정책 안에서 같은 테이블을 다시 읽으면 재귀가 나서 definer 함수로 분리)
create or replace function public.copy_answered(b text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.taglines t where t.brief_id = b and t.added_by = public.me())
$$;
-- 브리프별로 누가 냈는지 (본문 없이)
create or replace function public.copy_status() returns table (brief_id text, author text, n bigint)
language sql stable security definer set search_path = '' as $$
  select t.brief_id, t.added_by, count(*) from public.taglines t
  where public.is_member() and t.brief_id is not null group by 1, 2
$$;
revoke execute on function public.copy_answered(text), public.copy_status() from public, anon;
grant execute on function public.copy_answered(text), public.copy_status() to authenticated;

-- 블라인드: 브리프 카피는 내가 그 브리프에 낸 뒤에만 남의 것이 보인다. 자유 카피(brief_id 없음)는 모두 보인다.
drop policy "shared rw" on public.taglines;
create policy "blind read" on public.taglines for select to authenticated
  using (public.is_member() and (brief_id is null or added_by = public.me() or public.copy_answered(brief_id)));
create policy "own insert" on public.taglines for insert to authenticated
  with check (public.is_member() and added_by = public.me());
create policy "own update" on public.taglines for update to authenticated
  using (public.is_member() and added_by = public.me()) with check (public.is_member() and added_by = public.me());
create policy "own delete" on public.taglines for delete to authenticated
  using (public.is_member() and added_by = public.me());

alter publication supabase_realtime add table public.copy_briefs;
