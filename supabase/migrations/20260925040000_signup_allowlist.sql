-- 회원가입 허용 목록: members 에 있는 이메일만 가입할 수 있다.
-- Supabase Auth "Before User Created" 훅으로 연결해야 동작한다
-- (Dashboard → Authentication → Hooks → Before User Created → Postgres → public.hook_before_user_created).
create or replace function public.hook_before_user_created(event jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.members where email = lower(event->'user'->>'email')) then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object(
    'http_code', 403,
    'message', '가입할 수 없는 이메일이에요. 등록된 멤버만 가입할 수 있어요.'));
end $$;

revoke execute on function public.hook_before_user_created(jsonb) from public, anon, authenticated;
grant execute on function public.hook_before_user_created(jsonb) to supabase_auth_admin;
