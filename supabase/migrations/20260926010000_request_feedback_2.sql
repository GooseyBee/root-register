-- 건의함 2차 반영 (2026-09-26, 혜림 님 건의 4건)

-- 1) 번역 연습 방향(한→영 / 영→한). 원문 칼럼을 방향과 상관없는 source 로 옮긴다.
--    ko 는 예전 화면 호환을 위해 남기되 비워 둘 수 있게 한다.
alter table public.drills add column dir text not null default 'KR→EN' check (dir in ('KR→EN','EN→KR'));
alter table public.drills add column source text;
update public.drills set source = ko where source is null;
alter table public.drills alter column source set not null;
alter table public.drills alter column ko drop not null;

-- 사람마다 번역 연습을 처음 열 때 보이는 방향 (희주 한→영, 혜림 영→한은 SQL Editor에서 설정)
alter table public.members add column drill_dir text not null default 'KR→EN' check (drill_dir in ('KR→EN','EN→KR'));

-- 2) 교차번역 추천 표현. 번역 연습의 drill_models 와 같은 모양.
--    내가 그 원문에 번역을 저장해야 읽을 수 있다(session_answered). 쓰기 정책 없음(Claude가 SQL로 넣는다).
create table public.session_models (
  session_id   text primary key references public.sessions(id) on delete cascade,
  best         text not null,
  alternatives jsonb not null default '[]'::jsonb,  -- [text]
  notes        jsonb not null default '[]'::jsonb   -- [{phrase, why}]
);
alter table public.session_models enable row level security;
create policy "answered read" on public.session_models for select to authenticated
  using (public.is_member() and public.session_answered(session_id));

-- 3) 피드백 요청: 내가 제출한 번역에 "왜 틀렸는지" 설명을 요청한다.
--    Claude가 확인할 때 answer 를 채운다(멤버는 answer 를 쓸 수 없다). 본인 것만 보인다.
create table public.feedback_requests (
  id          uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('drill','session')),
  target_id   text not null,
  author      text not null default public.me(),
  created_at  timestamptz not null default now(),
  answer      text not null default '',
  answered_at timestamptz,
  unique (target_type, target_id, author)
);
alter table public.feedback_requests enable row level security;
create policy "own read" on public.feedback_requests for select to authenticated
  using (public.is_member() and author = public.me());
create policy "own insert" on public.feedback_requests for insert to authenticated
  with check (public.is_member() and author = public.me() and answer = '' and answered_at is null);
create policy "own delete" on public.feedback_requests for delete to authenticated
  using (public.is_member() and author = public.me());

-- 4) 내 오답 노트: 자주 틀리는 표현. Claude가 피드백을 쓰면서 모으고, 같은 실수가 또 나오면 count 를 올린다.
create table public.mistake_notes (
  id         uuid primary key default gen_random_uuid(),
  author     text not null,           -- 이 실수를 한 사람
  lang       text not null check (lang in ('en','ko')),  -- 틀린 표현이 어느 언어인지
  wrong      text not null,           -- 내가 쓴 표현
  better     text not null,           -- 더 나은 표현
  why        text not null default '',
  count      int  not null default 1,
  last_seen  date not null default current_date,
  created_at timestamptz not null default now()
);
alter table public.mistake_notes enable row level security;
create policy "own read" on public.mistake_notes for select to authenticated
  using (public.is_member() and author = public.me());

alter publication supabase_realtime add table public.feedback_requests, public.mistake_notes;
