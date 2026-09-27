-- 🔔 알림 읽음 표시: 자체 읽음 칸이 없는 알림(교차번역 저장, 새 건의, 상대의 피드백 요청)의 읽음을 사람별로 적는다.
-- 피드백·정밀 검토·리포트·건의 완료는 원래 테이블의 seen_at 칸을 그대로 쓴다.
create table public.notif_reads (
  author  text not null default public.me(),
  key     text not null,            -- 예: nudge:<원문 id>, req:<건의 id>, q:<요청자>|<요청 시각>
  read_at timestamptz not null default now(),
  primary key (author, key)
);
alter table public.notif_reads enable row level security;
create policy "own" on public.notif_reads for all to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());
