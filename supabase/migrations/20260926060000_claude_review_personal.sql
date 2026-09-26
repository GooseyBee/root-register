-- Claude 정밀 검토 + 오답 노트 기반 맞춤 문장·주간 리포트 (2026-09-26)

-- 1) Claude 정밀 검토: Gemini 즉시 답과 별도로, 요청하면 Claude가 더 깊게 보고 Gemini 답도 검수한다.
alter table public.feedback_requests
  add column claude_requested_at timestamptz,
  add column claude_answer       text not null default '',
  add column claude_answered_at  timestamptz,
  add column claude_verdict      text not null default '' check (claude_verdict in ('', 'ok', 'fixed')),  -- Gemini 답 검수 결과
  add column claude_seen_at      timestamptz;
-- 멤버가 고칠 수 있는 칸: 읽음 표시 2개 + 정밀 검토 요청 시각
grant update (claude_requested_at, claude_seen_at) on public.feedback_requests to authenticated;

-- 관리자 현황에 정밀 검토 상태도 보여 준다 (반환 모양이 바뀌어서 다시 만든다)
drop function public.feedback_queue();
create function public.feedback_queue()
returns table (author text, target_type text, created_at timestamptz, answered_at timestamptz, error text,
               claude_requested_at timestamptz, claude_answered_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select f.author, f.target_type, f.created_at, f.answered_at, f.error, f.claude_requested_at, f.claude_answered_at
  from public.feedback_requests f
  where exists (select 1 from public.members m where m.email = public.me() and m.is_admin)
    and f.created_at > now() - interval '14 days'
$$;
revoke execute on function public.feedback_queue() from public, anon;
grant execute on function public.feedback_queue() to authenticated;

-- 2) 맞춤 문장: 주간 루틴이 오답 노트를 보고 특정 사람을 위해 넣는 문장
alter table public.drills
  add column for_author text,                     -- 누구를 위한 문장인지 (없으면 모두)
  add column focus      text not null default ''; -- 어떤 실수를 연습하는지 (예: '~에 대한' 번역투)

-- 3) 주간 리포트: 사람마다 한 주의 실수 패턴과 고치는 법. 루틴이 쓰고 본인만 본다.
create table public.weekly_reports (
  id         uuid primary key default gen_random_uuid(),
  author     text not null,
  week_of    date not null,             -- 그 주 월요일 (한국 시간)
  body       text not null,
  created_at timestamptz not null default now(),
  seen_at    timestamptz,
  unique (author, week_of)
);
alter table public.weekly_reports enable row level security;
create policy "own read" on public.weekly_reports for select to authenticated
  using (public.is_member() and author = public.me());
create policy "own seen" on public.weekly_reports for update to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());
revoke update on public.weekly_reports from anon, authenticated;
grant update (seen_at) on public.weekly_reports to authenticated;
alter publication supabase_realtime add table public.weekly_reports;

-- 4) 알림 훅: Claude 답이 달리면 요청한 사람에게, 주간 리포트가 들어오면 그 사람에게 (pg_net → assist)
create or replace function public.hook_post(payload jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare s text;
begin
  select value into s from private.app_secrets where name = 'hook_secret';
  if s is null then return; end if;
  perform net.http_post(
    url     := 'https://djhrnlatrtrfmmcjekqk.supabase.co/functions/v1/assist',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-hook-secret', s),
    body    := payload);
end $$;
revoke execute on function public.hook_post(jsonb) from public, anon, authenticated;

create or replace function public.notify_claude_answer() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.claude_answered_at is not null and old.claude_answered_at is null then
    new.claude_seen_at := null;
    perform public.hook_post(jsonb_build_object('action', 'claude-answered', 'id', new.id));
  end if;
  return new;
end $$;
create trigger feedback_claude_answered before update of claude_answered_at on public.feedback_requests
  for each row execute function public.notify_claude_answer();

create or replace function public.notify_report() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.hook_post(jsonb_build_object('action', 'report-added', 'id', new.id));
  return new;
end $$;
create trigger weekly_reports_notify after insert on public.weekly_reports
  for each row execute function public.notify_report();
