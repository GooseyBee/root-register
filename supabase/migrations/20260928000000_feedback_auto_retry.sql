-- Gemini 과부하(503)·한도(429)로 실패한 피드백 요청을 10분마다 자동으로 다시 보낸다 (최대 3번, 2026-09-28)
-- 사용자 요청 1번 + 재시도 2번. 3번째까지 실패하면 assist가 희주에게 알리고, Claude 정밀 검토 루틴이 대신 답한다.
create extension if not exists pg_cron;

create or replace function public.retry_failed_feedback() returns int
language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
  for r in
    select id from public.feedback_requests
    where answered_at is null and claude_answered_at is null and error <> ''
      and tries < 3 and created_at > now() - interval '1 day'
    order by created_at limit 10
  loop
    perform public.hook_post(jsonb_build_object('action', 'feedback-retry', 'id', r.id));
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.retry_failed_feedback() from public, anon, authenticated;

select cron.schedule('retry-failed-feedback', '*/10 * * * *', $$select public.retry_failed_feedback()$$);
