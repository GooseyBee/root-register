-- 보안 점검(advisor) 반영: search_path 고정, anon의 is_member() 실행 권한 회수
-- authenticated 는 RLS 정책 평가에 is_member() 가 필요하므로 유지한다.
create or replace function public.me() returns text
language sql stable set search_path = '' as $$ select lower(auth.jwt() ->> 'email') $$;

revoke execute on function public.is_member() from public, anon;
grant execute on function public.is_member() to authenticated;
