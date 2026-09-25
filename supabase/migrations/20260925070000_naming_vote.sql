-- 이름 정하기: 후보(name_candidates)와 투표(name_votes).
-- 후보 풀은 Claude가 미리 써서 넣고(AI API 호출 없음), 앱은 shown=false인 후보를 "다시 추천하기"로 꺼내 보여 준다.
create table public.name_candidates (
  id          text primary key default gen_random_uuid()::text,
  name        text not null check (length(trim(name)) > 0),
  gloss       text not null default '',   -- 한 줄 뜻
  why         text not null default '',   -- 왜 어울리는지
  sort        int  not null default 1000,
  shown       boolean not null default false,
  excluded    boolean not null default false,
  excluded_by text,
  excluded_at timestamptz,
  added_by    text default public.me(),   -- Claude가 넣은 후보는 null
  created_at  timestamptz not null default now()
);

create table public.name_votes (
  candidate_id text not null references public.name_candidates(id) on delete cascade,
  author       text not null default public.me(),
  created_at   timestamptz not null default now(),
  primary key (candidate_id, author)
);

alter table public.name_candidates enable row level security;
alter table public.name_votes      enable row level security;

create policy "read" on public.name_candidates for select to authenticated using (public.is_member());
create policy "member add" on public.name_candidates for insert to authenticated
  with check (public.is_member() and added_by = public.me());
create policy "member update" on public.name_candidates for update to authenticated
  using (public.is_member()) with check (public.is_member());

-- 멤버는 직접 후보를 추가하거나(이름·뜻·이유), 보이기/빼기 상태만 바꿀 수 있다.
revoke insert, update, delete on public.name_candidates from anon, authenticated;
grant insert (name, gloss, why, shown) on public.name_candidates to authenticated;
grant update (shown, excluded, excluded_by, excluded_at) on public.name_candidates to authenticated;

create policy "read" on public.name_votes for select to authenticated using (public.is_member());
create policy "own insert" on public.name_votes for insert to authenticated
  with check (public.is_member() and author = public.me());
create policy "own delete" on public.name_votes for delete to authenticated
  using (public.is_member() and author = public.me());

alter publication supabase_realtime add table public.name_candidates, public.name_votes;
