-- 코멘트 답장 + 건의 완료 알림 (2026-09-26)

-- 1) 답장: parent_id. 답장은 부모와 같은 대상(target)에 붙고, 답장의 답장은 한 단계(맨 위 코멘트)로 모은다.
--    대상은 트리거가 부모에서 복사하므로, 번역 연습 코멘트의 "제출한 사람에게만" 규칙이 답장에도 그대로 적용된다.
alter table public.comments add column parent_id uuid references public.comments(id) on delete cascade;
create index comments_parent on public.comments (parent_id);

create or replace function public.comment_inherit_target() returns trigger
language plpgsql security definer set search_path = '' as $$
declare p record;
begin
  if new.parent_id is not null then
    select c.target_type, c.target_id, c.parent_id into p from public.comments c where c.id = new.parent_id;
    if not found then raise exception 'parent comment not found'; end if;
    new.target_type := p.target_type;
    new.target_id   := p.target_id;
    new.parent_id   := coalesce(p.parent_id, new.parent_id);
  end if;
  return new;
end $$;
create trigger comments_inherit_target before insert on public.comments
  for each row execute function public.comment_inherit_target();

-- 2) 건의가 완료되면 올린 사람에게 알림
--    상태는 Claude가 SQL로 바꾼다 → 트리거가 pg_net 으로 Edge Function(assist)을 부르고, 함수가 웹 푸시를 보낸다.
--    함수 호출은 private.app_secrets 의 hook_secret 으로 인증한다(값은 저장소에 넣지 않는다).
create extension if not exists pg_net with schema extensions;

-- 올린 사람이 앱에서 완료 알림을 봤는지(🔔에서 사라지게)
alter table public.requests add column done_seen_at timestamptz;
update public.requests set done_seen_at = now() where status = 'done';
grant update (done_seen_at) on public.requests to authenticated;

create or replace function public.notify_request_done() returns trigger
language plpgsql security definer set search_path = '' as $$
declare s text;
begin
  if new.status = 'done' and old.status is distinct from 'done' then
    new.done_seen_at := null;
    select value into s from private.app_secrets where name = 'hook_secret';
    if s is not null then
      perform net.http_post(
        url     := 'https://djhrnlatrtrfmmcjekqk.supabase.co/functions/v1/assist',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-hook-secret', s),
        body    := jsonb_build_object('action', 'request-done', 'id', new.id)
      );
    end if;
  end if;
  return new;
end $$;
create trigger requests_notify_done before update of status on public.requests
  for each row execute function public.notify_request_done();
