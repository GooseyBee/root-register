# Root & Register (뿌리와 결)

통번역사와 카피라이터가 함께 쓰는 어원·격(사용역) 학습 웹앱이에요. 두 사람이 서로 가르치면서 배우는 6개월(12회) 공동 학습 프로그램을 도와요.

- **오늘의 문장** (첫 화면): 하루 한 문장, 영어만 먼저 보여 줘요. 누르면 한글 뜻, 설명, 어려운 단어 풀이가 펼쳐져요. 두 사람이 같은 문장을 봐요.
- **번역 연습**: 주제별(마케팅·광고, 비즈니스·이메일, 일상 회화, 여행 표현) 한국어 문장을 각자 영어로 번역해 제출해요. 내가 제출해야 상대 번역이 보이고(블라인드), 내가 제출하면 추천 표현과 포인트가 열려요. 번역 연습 코멘트는 그 문장을 제출한 사람에게만 보여요(스포 방지). 개인 피드백은 Claude Code에 채팅으로 요청하면 코멘트로 남겨요.
- **오늘의 복습**: 5단계 간격 반복 복습이에요. 진도는 사람마다 따로 저장돼요.
- **용어집**: 격·분야·언어로 필터링할 수 있어요. 영어 용어는 단어와 예문만 먼저 보여 주고, 누르면 뜻이 펼쳐져요.
- **함께 번역** (예전 이름: 세션 기록): 원문을 올리고 각자 번역한 뒤 합의안과 메모를 함께 적어요. 원문마다 난이도(쉬움·보통·실전)가 있고 난이도별로 골라 볼 수 있어요.
- **태그라인 보드**: 친구가 올린 영어 태그라인에 피드백해요.
- **즐겨찾기(★)와 코멘트**: 용어, 세션, 태그라인, 오늘의 문장마다 달 수 있어요. 즐겨찾기는 사람마다 따로 저장되고, 목록마다 "즐겨찾기만 보기"가 있어요.
- **건의함**: 앱을 어떻게 바꾸고 싶은지 올리는 게시판이에요. Claude Code 세션에서 "건의함 확인해줘"라고 하면 Claude가 새 건의를 읽고 요약해 줘요. 희주 님이 승인하면 반영하고, 상태와 처리 메모를 달아요. 상태와 메모는 앱에서 바꿀 수 없고 Claude만 SQL로 갱신해요.
- **요금 없음**: 앱은 AI를 호출하지 않아요. 예문, 설명, 단어 풀이는 데이터로 미리 넣어 둬요. Vercel Hobby와 Supabase Free 플랜만 써요.

배포 주소: https://root-register.vercel.app

커리큘럼 문서: https://claude.ai/code/artifact/1c3f2a9e-ef9a-4133-a30c-5a58af927c16

## 구조

```
docs/                    정적 사이트 (Vercel이 main 브랜치의 docs/를 배포)
  index.html             앱 전체 (바닐라 JS, supabase-js UMD)
  config.js              Supabase URL + anon key (공개용 키)
supabase/
  migrations/            테이블, RLS 정책, realtime 설정
  seed.sql               예시 데이터 (용어 13개, 세션 원문 2개)
  data/                  예문 설명·단어 풀이 등 추가 데이터 SQL
  functions/examples/    사용 중지 (AI 호출 제거, 410 응답만 반환)
scripts/
  artifact-to-seed.mjs   claude.ai artifact DB에서 내보낸 JSON → seed.sql
notes/
  changelog.md           작업 기록 전체 (최신순, 목차 포함)
```

```mermaid
flowchart LR
  B[브라우저<br/>docs/index.html] -->|로그인 링크 로그인| A[Supabase Auth]
  B -->|읽기·쓰기, RLS| D[(Postgres)]
  D -->|realtime| B
  B -->|rpc ensure_daily| D
```

### 접근 제어

- 로그인한 이메일이 `members` 테이블에 있어야 읽고 쓸 수 있어요. RLS의 `is_member()`가 이를 검사해요.
- 복습 진도(`reviews`), 즐겨찾기(`favorites`)는 본인만 보고 고칠 수 있어요. 세션 번역(`session_versions`), 코멘트(`comments`)는 함께 보고 작성자 본인만 고칠 수 있어요.
- 번역 연습: `drill_answers`는 본인 것과, 내가 제출한 문장의 남의 답만 보여요(`drill_answered()`). `drill_models`(추천 표현)는 내가 제출한 문장만 읽을 수 있어요(`drill_answered()`). 번역 연습 코멘트(`comments`, `target_type='drill'`)도 제출한 사람과 작성자에게만 보여요. 누가 제출했는지는 본문 없이 `drill_status()`로 알려 줘요.
- 오늘의 문장은 `ensure_daily()`가 서울 날짜 기준으로 하루 1개를 용어집 영어 예문에서 골라 `daily_sentences`에 저장해요.
- `docs/config.js`의 anon key는 공개돼도 괜찮은 키예요. 데이터는 RLS가 막아요.

## 설정 방법

1. Supabase 프로젝트를 만들고 SQL Editor에서 `supabase/migrations/*.sql`(파일명 순서대로), `supabase/seed.sql`, `supabase/data/*.sql`을 차례로 실행해요.
2. 멤버를 등록해요. 이메일은 저장소에 넣지 않고 SQL Editor에서만 실행해요.
   ```sql
   insert into public.members (email, display_name) values
     ('나의 이메일', '이름'), ('친구 이메일', '이름');
   ```
3. Authentication → URL Configuration에서 Site URL과 Redirect URL에 배포 주소를 넣어요.
   Authentication → Hooks → **Before User Created**에 Postgres 함수 `public.hook_before_user_created`를 연결해요. 이렇게 하면 `members`에 있는 이메일만 가입할 수 있어요.
4. `docs/config.js`에 프로젝트 URL과 anon key를 넣어요.
5. Vercel에서 이 저장소를 Import하고 Root Directory를 `docs`, Framework Preset을 `Other`로 두면(빌드 명령 없음) main에 push할 때마다 자동으로 배포돼요.

새 용어의 예문과 설명은 직접 입력하거나(`문장 | 번역` 형식), Claude Code에 부탁해 DB에 넣어요. 앱이 API를 호출하지 않으니 요금이 나오지 않아요.

## 작업 기록

전체 기록은 [notes/changelog.md](notes/changelog.md)에 최신순으로 있어요. 최근 5개:

| 날짜 | 작업 |
|---|---|
| 2026-09-25 | [함께 번역 화면에서 '세션'이라는 말 없애기](notes/changelog.md#2026-09-25--함께-번역-화면에서-세션이라는-말-없애기) |
| 2026-09-25 | [건의 반영: 번역 연습 공개 조건, 함께 번역 난이도·이름](notes/changelog.md#2026-09-25--건의-반영-번역-연습-공개-조건-함께-번역-난이도이름) |
| 2026-09-25 | [작업 기록을 notes/changelog.md로 분리](notes/changelog.md#2026-09-25--작업-기록을-noteschangelogmd로-분리) |
| 2026-09-25 | [Vercel과 GitHub 연결 (자동 배포)](notes/changelog.md#2026-09-25--vercel과-github-연결-자동-배포) |
| 2026-09-25 | [메뉴를 좌측 상단으로, 모바일은 햄버거 버튼](notes/changelog.md#2026-09-25--메뉴를-좌측-상단으로-모바일은-햄버거-버튼) |
