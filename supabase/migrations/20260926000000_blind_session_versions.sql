-- 교차번역(구 함께 번역): 내 번역을 저장해야 상대 번역이 보인다 (혜림 님 건의, 2026-09-26).
-- 합의안·메모(sessions.final/notes)는 모임에서 같이 쓰는 칸이라 그대로 둘 다 보인다.

-- 내가 이 원문에 번역을 저장했는가 (정책 안에서 같은 테이블을 다시 읽으면 재귀가 나서 definer 함수로 분리)
create or replace function public.session_answered(s text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.session_versions v where v.session_id = s and v.author = public.me() and length(trim(v.body)) > 0)
$$;
-- 원문별로 누가 저장했는지 (본문 없이)
create or replace function public.session_version_status() returns table (session_id text, author text)
language sql stable security definer set search_path = '' as $$
  select v.session_id, v.author from public.session_versions v
  where public.is_member() and length(trim(v.body)) > 0
$$;
revoke execute on function public.session_answered(text), public.session_version_status() from public, anon;
grant execute on function public.session_answered(text), public.session_version_status() to authenticated;

drop policy "read" on public.session_versions;
create policy "blind read" on public.session_versions for select to authenticated
  using (public.is_member() and (author = public.me() or public.session_answered(session_id)));
