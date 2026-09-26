-- 피드백 자동 답변(Gemini 무료 API) + 앱 안 알림 + 웹 푸시 (2026-09-26)

-- 1) 비밀값 보관: API로 노출되지 않는 private 스키마. Edge Function(service_role)만 app_secret()으로 읽는다.
--    값(VAPID 비공개 키, 필요하면 Gemini 키)은 저장소에 넣지 않고 SQL Editor에서 넣는다.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table if not exists private.app_secrets (name text primary key, value text not null);
create or replace function public.app_secret(n text) returns text
language sql stable security definer set search_path = '' as $$
  select value from private.app_secrets where name = n
$$;
revoke execute on function public.app_secret(text) from public, anon, authenticated;
grant execute on function public.app_secret(text) to service_role;

-- 2) 피드백 요청: 읽음 표시, 실패 기록, 누가 답했는지(gemini / claude)
alter table public.feedback_requests
  add column seen_at timestamptz,
  add column error   text not null default '',
  add column tries   int  not null default 0,
  add column by      text not null default '';
update public.feedback_requests set by = 'claude' where answered_at is not null and by = '';
-- 멤버는 seen_at 만 고칠 수 있다(답변은 Edge Function/Claude만 쓴다)
revoke update on public.feedback_requests from anon, authenticated;
grant update (seen_at) on public.feedback_requests to authenticated;
create policy "own seen" on public.feedback_requests for update to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());

-- 3) 관리자(희주): 두 사람의 피드백 요청 현황과 새 건의 알림을 받는다. 값은 SQL Editor에서 켠다.
alter table public.members add column is_admin boolean not null default false;

-- 관리자에게만 최근 2주 피드백 요청 현황(본문 없이)을 보여 준다
create or replace function public.feedback_queue()
returns table (author text, target_type text, created_at timestamptz, answered_at timestamptz, error text)
language sql stable security definer set search_path = '' as $$
  select f.author, f.target_type, f.created_at, f.answered_at, f.error
  from public.feedback_requests f
  where exists (select 1 from public.members m where m.email = public.me() and m.is_admin)
    and f.created_at > now() - interval '14 days'
$$;
revoke execute on function public.feedback_queue() from public, anon;
grant execute on function public.feedback_queue() to authenticated;

-- 4) 웹 푸시 구독 (기기마다 1행)
create table public.push_subscriptions (
  endpoint   text primary key,
  author     text not null default public.me(),
  p256dh     text not null,
  auth       text not null,
  created_at timestamptz not null default now()
);
alter table public.push_subscriptions enable row level security;
create policy "own all" on public.push_subscriptions for all to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());
