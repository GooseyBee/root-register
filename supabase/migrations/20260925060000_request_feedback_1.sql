-- 건의함 1차 반영 (2026-09-25, 우혜림 님 건의 2건)

-- 1) 번역 연습: 추천 표현은 "모두 제출"이 아니라 "내가 제출"하면 읽을 수 있다.
--    상대 번역은 기존대로 내가 제출해야 보이므로(blind read) 블라인드 원칙은 유지된다.
drop policy "revealed read" on public.drill_models;
create policy "answered read" on public.drill_models for select to authenticated
  using (public.is_member() and public.drill_answered(drill_id));

-- 2) 번역 연습 코멘트는 그 문장을 제출한 사람에게만 보인다 (스포 방지). 내 코멘트는 항상 보인다.
drop policy "read" on public.comments;
create policy "read" on public.comments for select to authenticated
  using (public.is_member() and (target_type <> 'drill' or author = public.me() or public.drill_answered(target_id)));

-- 3) 함께 번역(구 세션 기록): 원문마다 난이도
alter table public.sessions add column level text not null default '보통' check (level in ('쉬움','보통','실전'));
update public.sessions set level = '실전';
