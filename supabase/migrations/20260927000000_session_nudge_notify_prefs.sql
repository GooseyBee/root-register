-- 교차번역 저장 알림 + 알림 종류별 켜고 끄기 (2026-09-27)

-- 1) 알림 설정: 끈 알림 종류만 적는다(기본은 모두 켜짐). 휴대폰 알림에만 적용하고, 앱 안 🔔 목록은 그대로 보여 준다.
--    종류: fb, claude, report, content, nudge, reply, done, admin-req, admin-fb (docs/index.html의 NOTIFY_KINDS와 같게)
create table public.notify_prefs (
  author     text primary key default public.me(),
  off        text[] not null default '{}',
  updated_at timestamptz not null default now()
);
alter table public.notify_prefs enable row level security;
create policy "own" on public.notify_prefs for all to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());

-- 2) 교차번역: 누가 원문에 번역을 처음 저장하면(빈 칸 → 내용) 아직 안 한 사람에게 "내 번역도 저장해요" 알림
create or replace function public.notify_session_saved() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if length(trim(new.body)) > 0 and (tg_op = 'INSERT' or length(trim(coalesce(old.body, ''))) = 0) then
    perform public.hook_post(jsonb_build_object('action', 'session-saved', 'session_id', new.session_id, 'author', new.author));
  end if;
  return new;
end $$;
create trigger session_versions_saved after insert or update of body on public.session_versions
  for each row execute function public.notify_session_saved();
