-- 🔔 알림에 시각을 붙이려고, 원문별 저장 현황에 저장 시각도 돌려준다 (본문은 여전히 안 돌려줌)
drop function public.session_version_status();
create function public.session_version_status() returns table (session_id text, author text, updated_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select v.session_id, v.author, v.updated_at from public.session_versions v
  where public.is_member() and length(trim(v.body)) > 0
$$;
revoke execute on function public.session_version_status() from public, anon;
grant execute on function public.session_version_status() to authenticated;
