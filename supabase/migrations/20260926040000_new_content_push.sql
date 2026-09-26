-- 새 콘텐츠 알림 (2026-09-26)
-- 번역 연습 문장이나 교차번역 원문이 들어오면(주간 루틴이든 앱에서 직접이든) 두 사람에게 휴대폰 알림.
-- 한 번에 여러 줄이 들어와도 알림은 한 번만 가도록 문장 단위(for each statement) 트리거로 센다.
create or replace function public.notify_new_content() returns trigger
language plpgsql security definer set search_path = '' as $$
declare s text; n int; ko int; en int;
begin
  select value into s from private.app_secrets where name = 'hook_secret';
  if s is null then return null; end if;
  if tg_table_name = 'drills' then
    select count(*), count(*) filter (where dir = 'EN→KR'), count(*) filter (where dir = 'KR→EN') into n, ko, en from new_rows;
  else
    select count(*), 0, 0 into n, ko, en from new_rows;
  end if;
  if n = 0 then return null; end if;
  perform net.http_post(
    url     := 'https://djhrnlatrtrfmmcjekqk.supabase.co/functions/v1/assist',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-hook-secret', s),
    body    := jsonb_build_object('action', 'content-added', 'kind', tg_table_name, 'n', n, 'enkr', ko, 'kren', en)
  );
  return null;
end $$;

create trigger drills_notify_new after insert on public.drills
  referencing new table as new_rows for each statement execute function public.notify_new_content();
create trigger sessions_notify_new after insert on public.sessions
  referencing new table as new_rows for each statement execute function public.notify_new_content();
