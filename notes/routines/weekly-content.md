# 주간 콘텐츠 추가 루틴 (Claude가 매주 월요일 오전 8:50에 실행)

Claude Code 루틴이 이 문서를 읽고 그대로 실행해요. 사람이 고치고 싶으면 이 파일을 고치면 돼요(다음 실행부터 반영).

- Supabase 프로젝트: `djhrnlatrtrfmmcjekqk` (Supabase 커넥터의 `execute_sql` 사용)
- 앱은 AI를 부르지 않아요. 문장과 추천 표현은 Claude가 직접 쓰고 검수해서 넣어요.
- 새 문장·원문이 DB에 들어가면 트리거가 두 사람에게 휴대폰 알림을 보내요. 그래서 **문장과 추천 표현을 한 트랜잭션으로** 넣어야 해요(알림을 받고 열었는데 추천 표현이 없는 일이 없게).

```mermaid
flowchart TD
  S[월요일 8:50 루틴 시작] --> R[기존 문장·진행 상황 읽기]
  R --> D[번역 연습: 방향마다 12문장 작성·검수<br/>그중 사람마다 2~4문장은 오답 노트 맞춤]
  R --> RP[주간 리포트: 사람마다 1개 → 알림]
  D --> I1[drills + drill_models 한 트랜잭션]
  R --> Q{교차번역 마지막 회차가<br/>10일 이상 지났나? 12회차 미만?}
  Q -->|예| X[다음 회차 원문 6개 + 추천 표현]
  X --> I2[sessions + session_models 한 트랜잭션]
  Q -->|아니오| K[건너뜀]
  I1 --> F[SQL 파일 저장 → main에 push]
  I2 --> F
  K --> F
```

## 1. 읽기
- [ ] `select id, dir, topic, context, source from drills order by created_at;` 로 기존 문장을 모두 읽어요. 같은 표현·같은 상황을 다시 쓰지 않아요.
- [ ] `select m.display_name, d.dir, count(a.*) from members m cross join (select distinct dir from drills) d left join drill_answers a on a.author=m.email and a.drill_id in (select id from drills where dir=d.dir) group by 1,2;` 로 진행 상황을 봐요(보고에만 써요).
- [ ] `select no, level, dir, title, created_at from sessions order by no desc, created_at desc;` 로 교차번역 마지막 회차와 날짜를 봐요.

> **한글 톤은 [`notes/style/korean-voice.md`](../style/korean-voice.md)를 따라요.** 마케팅은 세련된 브랜드 카피(상투어·재촉·최상급 금지), 비즈니스는 깔끔하게, 일상은 요즘 구어, 안내문은 실제 안내문 말투. 번역투(~을 통해, ~에 대한)는 빼요.

## 2. 번역 연습 (매주)
방향마다 12문장, 주제(`marketing`, `business`, `daily`, `travel`)마다 3문장씩, 모두 24문장.

| 방향 | 원문 | 추천 표현 | 누구 기본 |
|---|---|---|---|
| `KR→EN` | 자연스러운 한국어 | 영어 | 희주 |
| `EN→KR` | 자연스러운 영어 | 한국어 | 혜림 |

- 원문은 1~2문장, 실제로 쓸 법한 상황(`context`에 한 줄로: 예 "호텔 체크인 안내", "거래처 회신 메일 마무리").
- 직역하면 어색해지는 포인트(관용 표현, 격, 어순, 주어 생략, 번역투)가 하나 이상 들어가게 골라요. 쉬운 문장과 조금 어려운 문장을 섞어요.
- 추천 표현: `best` 1개, `alternatives` 2개, `notes` 2~3개(`phrase`, `why`: 직역하면 왜 어색한지, 격이 어떻게 다른지). 설명은 해요체.
- 실존 회사·인물·통계·시사 사실은 쓰지 않아요(틀릴 수 있어서).
- **검수**: 넣기 전에 문장마다 다시 읽고 확인해요. 영어는 원어민이 실제로 쓰는 말인지, 관용 표현의 뜻이 맞는지, 한국어는 번역투 없이 자연스러운지, 맞춤법과 띄어쓰기가 맞는지. 확신이 없는 관용 표현은 웹 검색으로 확인하거나 다른 표현으로 바꿔요.
- id: `dr-YYYYMMDD-ke-m1`(한→영 마케팅 1), `dr-YYYYMMDD-ek-t3`(영→한 여행 3)처럼 날짜(한국 시간)·방향·주제·번호. `sort`는 주제 안에서 1~3.

```sql
begin;
insert into public.drills (id, dir, topic, sort, context, source) values
  ('dr-20261005-ke-m1','KR→EN','marketing',1,'상황','원문'),
  ...;  -- 24문장을 한 문장(statement)으로. 알림이 한 번만 가요.
insert into public.drill_models (drill_id, best, alternatives, notes) values
  ('dr-20261005-ke-m1','best','["alt1","alt2"]','[{"phrase":"...","why":"..."}]'),
  ...;
commit;
```
작은따옴표는 `''`로 이스케이프해요.

### 2-1. 맞춤 문장 (오답 노트 기반)
24문장 가운데 **사람마다 2~4문장**은 그 사람의 실수 패턴을 겨냥해 써요. 위와 같은 트랜잭션, 같은 insert 문 안에 넣어요(알림이 한 번만 가요).
- [ ] 오답 노트 읽기: `select m.display_name, n.author, n.lang, n.wrong, n.better, n.why, n.count, n.last_seen from mistake_notes n join members m on m.email = n.author order by n.author, n.count desc, n.last_seen desc;`
- [ ] 사람마다 자주 틀린(count 높은 순)·최근 틀린 패턴 1~2개를 골라, 그 함정이 자연스럽게 들어간 **새 문장**을 써요. 틀렸던 문장을 그대로 다시 내지 않아요.
- [ ] 방향은 그 사람의 기본 방향(위 표)으로 해요.
- [ ] `for_author`에 그 사람 이메일(쿼리 결과의 `author`), `focus`에 연습 포인트 한 줄(예: `'~에 대한' 번역투`, `'meet'을 직역`). 화면에 "나를 위한 문장 · (focus)"로 보여요.
- [ ] 오답 노트가 비어 있는 사람은 맞춤 문장 없이 보통 문장으로 채워요.

```sql
insert into public.drills (id, dir, topic, sort, context, source, for_author, focus) values
  ('dr-20261005-ek-b3','EN→KR','business',3,'상황','원문','<author>','연습 포인트'), ...
```
(보통 문장과 한 insert로 묶으려면 모든 행에 `for_author`는 `null`, `focus`는 `''`로 채워요.)

### 2-2. 주간 리포트
- [ ] 오답 노트가 있는 사람마다 `weekly_reports`에 1개(`week_of` = 그 주 월요일, 한국 시간). 이미 있으면 건너뛰어요.
- [ ] 이번 주 활동 수: `select author, count(*) from drill_answers where updated_at > now() - interval '7 days' group by 1;` / `select author, count(*) from feedback_requests where created_at > now() - interval '7 days' group by 1;`
- [ ] 본문(해요체, 12줄 이내, 마크다운 기호 없이, 톤은 스타일 가이드):
  1. 지난 한 주 요약 한 줄 (번역 수, 피드백 요청 수)
  2. 자주 틀린 것 3가지: "내가 쓴 표현 → 더 나은 표현"과 한 줄 이유
  3. 좋아진 점 한 가지 (최근 덜 틀린 패턴이 있으면)
  4. "이번 주 번역 연습에 나를 위한 문장 N개를 넣었어요"
- [ ] 넣으면 트리거가 그 사람에게 "이번 주 리포트" 휴대폰 알림을 보내요. 따로 보낼 필요 없어요.

```sql
insert into public.weekly_reports (author, week_of, body) values ('<author>', '2026-10-05', '...')
on conflict (author, week_of) do nothing;
```

## 3. 교차번역 (2주마다)
- [ ] 가장 큰 `no`(회차)의 원문이 **한국 시간 기준 10일 이상 전**에 올라왔고 `no < 12`일 때만 다음 회차(`no + 1`)를 추가해요. 아니면 건너뛰어요. 모임 요일이 정해지면 이 규칙을 바꿔요.
- [ ] 원문 6개: 난이도 `쉬움`·`보통`·`실전` × 방향 `KR→EN`·`EN→KR`.

| 난이도 | 기준 |
|---|---|
| 쉬움 | 1~2문장, 일상 대화·안내문 |
| 보통 | 2~3문장, 생활 기사체, 전문 용어 없음 |
| 실전 | 3문장 안팎, 기사체. 경제·사회·문화 주제. 가상의 사례로 쓰고 실제 사실처럼 쓰지 않아요 |

- 제목(`title`)은 "분류 · 주제" 형식(예: "안내문 · 헬스장 휴관", "생활 기사 · 수면").
- 추천 표현(`session_models`)도 같은 트랜잭션에 넣어요. `session_id`는 방금 넣은 행의 id를 써요(`insert ... returning id` 또는 제목으로 조회).

```sql
begin;
with s as (
  insert into public.sessions (no, dir, level, title, source) values
    (2,'KR→EN','쉬움','일상 · ...','...'),
    ... -- 6개를 한 문장으로
  returning id, title
)
insert into public.session_models (session_id, best, alternatives, notes)
select s.id, m.best, m.alternatives::jsonb, m.notes::jsonb
from s join (values ('일상 · ...','best','["..."]','[{"phrase":"...","why":"..."}]'), ...) as m(title,best,alternatives,notes)
  on m.title = s.title;
commit;
```

## 4. 기록과 보고
- [ ] 넣은 SQL을 `supabase/data/YYYYMMDD_weekly_content.sql`로 저장하고 `main`에 커밋·push해요(커밋 메시지: `Weekly content YYYY-MM-DD: 24 drills (+ session N)`).
- [ ] 확인 쿼리: 새 id의 `drills`·`drill_models` 개수가 각각 24인지, 교차번역을 넣었으면 `sessions`·`session_models`가 6인지.
- [ ] 마지막에 한국어로 짧게 보고해요: 넣은 개수(그중 맞춤 문장은 누구에게 몇 개), 주간 리포트를 받은 사람, 교차번역 추가 여부(건너뛰었으면 이유), 두 사람의 진행 상황.
- 실패하면(커넥터 오류 등) 아무것도 반쯤 넣지 말고(트랜잭션 롤백) 무엇이 실패했는지 보고해요.
