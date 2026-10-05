-- 다시 도전 (혜림 님 건의, 2026-10-05): 제출한 번역 연습 문장을 1주일 뒤에 지난 번역을 숨긴 채 다시 번역한다.
-- 1차 = drill_answers(처음 제출), 2차·3차 = 여기. 각 차수는 앞 차수에서 7일 이상 지나야 열린다(화면에서 계산).
-- 제출하면 지난 번역들과 나란히 보여 주고, 원하면 Gemini가 "무엇이 달라졌는지, 왜 같은 표현을 반복하는지"를 분석해 analysis에 남긴다.
-- 개인 복습 기록이라 본인만 읽고 쓴다(오답 노트·하이라이트처럼).
create table public.drill_retries (
  id          uuid primary key default gen_random_uuid(),
  drill_id    text not null references public.drills(id) on delete cascade,
  author      text not null default public.me(),
  attempt     int  not null check (attempt in (2, 3)),
  body        text not null check (length(trim(body)) > 0),
  analysis    text not null default '',
  analyzed_at timestamptz,
  created_at  timestamptz not null default now(),
  unique (drill_id, author, attempt)
);
create index drill_retries_author on public.drill_retries (author, created_at desc);
alter table public.drill_retries enable row level security;
create policy "own" on public.drill_retries for all to authenticated
  using (public.is_member() and author = public.me()) with check (public.is_member() and author = public.me());
alter publication supabase_realtime add table public.drill_retries;
