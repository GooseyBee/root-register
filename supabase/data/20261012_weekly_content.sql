-- 주간 콘텐츠 2026-10-12 (월): 번역 연습 5문장(EN→KR 3, KR→EN 2) + 주간 리포트 2 + 영어 카피 브리프 3 + 복습 단어 7
-- 교차번역은 지난 회차(10/05)에서 7일밖에 안 지나 이번 주는 쉬어요(2주마다).
-- 이메일은 저장하지 않고 이름으로 찾아요(members.display_name).
begin;
insert into public.drills (id, dir, topic, sort, context, source, for_author, focus) values
  ('dr-20261012-ke-d1','KR→EN','daily',1,'친구에게 주말 약속 확인 문자','토요일 약속 아직 유효하지? 그날 저녁엔 사촌 집들이가 있어서 점심만 같이 먹을 수 있을 것 같아.',(select email from public.members where display_name='희주'),'약속·모임 단어(plans, housewarming)'),
  ('dr-20261012-ke-b1','KR→EN','business',1,'거래처에 견적 회신 기한 안내','이 견적은 이번 달 말까지 유효합니다. 진행을 원하시면 수요일까지 회신 부탁드립니다.',(select email from public.members where display_name='혜림'),'''~까지'' until과 by 구분'),
  ('dr-20261012-ek-t1','EN→KR','travel',1,'호텔 엘리베이터 안내문','The rooftop pool is open to guests only. Towels are provided at the entrance.',null,''),
  ('dr-20261012-ek-m1','EN→KR','marketing',1,'중고 카메라 매장 SNS 소개글','Every camera here has had a life before. We just make sure it gets a second one.',null,''),
  ('dr-20261012-ek-b1','EN→KR','business',1,'회의 끝에 팀장이 하는 말','Let''s circle back on this next week once we have the numbers.',null,'');
insert into public.drill_models (drill_id, best, alternatives, notes) values
  ('dr-20261012-ke-d1','Are we still on for Saturday? I''ve got my cousin''s housewarming that evening, so I can probably only do lunch.','["Is Saturday still happening? My cousin''s having a housewarming party that night, so I think I can only make lunch.", "We''re still good for Saturday, right? I have my cousin''s housewarming in the evening, so lunch is probably all I can do."]','[{"phrase": "약속 아직 유효하지? → Are we still on for ~?", "why": "Is our appointment still valid?는 병원 예약처럼 딱딱해요. 친구 약속은 still on으로 물어요."}, {"phrase": "집들이 → housewarming (party)", "why": "새집에 사람을 부르는 모임은 housewarming이에요. house party는 그냥 집에서 여는 파티예요."}, {"phrase": "점심만 같이 먹을 수 있다 → I can only do lunch", "why": "구어에서 do lunch는 ''점심 먹기로 하다''예요. eat lunch together보다 짧고 자연스러워요."}]'),
  ('dr-20261012-ke-b1','This quote is valid until the end of the month. If you''d like to go ahead, please reply by Wednesday.','["The prices in this quote are good through the end of this month. Should you wish to proceed, we''d appreciate a reply by Wednesday.", "This quotation remains valid until month-end. To move forward, please get back to us by Wednesday."]','[{"phrase": "말까지 유효 → valid until", "why": "그때까지 쭉 이어지는 상태는 until이에요. 유효한 상태가 월말까지 계속돼요."}, {"phrase": "수요일까지 회신 → reply by Wednesday", "why": "그 시점 전에 한 번 끝내면 되는 일은 by예요. reply until Wednesday는 수요일까지 계속 답장하라는 뜻이 돼요."}, {"phrase": "진행을 원하시면 → If you''d like to go ahead", "why": "If you want progress는 어색해요. 거래를 진행할 때는 go ahead, proceed를 써요."}]'),
  ('dr-20261012-ek-t1','루프톱 수영장은 투숙객 전용입니다. 수건은 입구에 비치되어 있습니다.','["옥상 수영장은 투숙객만 이용하실 수 있습니다. 수건은 입구에 있습니다.", "루프톱 수영장은 호텔 투숙객 전용 시설입니다. 수건은 입구에서 가져가세요."]','[{"phrase": "open to guests only → 투숙객 전용입니다", "why": "''손님에게만 열려 있습니다''는 번역투예요. 호텔 안내문은 ''전용'', ''~만 이용하실 수 있습니다''로 써요."}, {"phrase": "are provided at → ~에 비치되어 있습니다", "why": "''제공됩니다''도 되지만 물건을 놓아 둔 안내에는 ''비치되어 있습니다''가 정해진 말이에요."}, {"phrase": "guests → 투숙객", "why": "호텔에서 guest는 ''손님''보다 ''투숙객''이 정확해요. 외부 방문객과 구분돼요."}]'),
  ('dr-20261012-ek-m1','이곳의 카메라는 모두 누군가의 손을 한 번 거쳤어요. 저희는 두 번째 주인을 만나게 할 뿐이에요.','["여기 있는 카메라는 모두 한 번씩 살아 본 적이 있어요. 저희는 두 번째 삶을 이어 줄 뿐이에요.", "모든 카메라에는 이전 주인과의 시간이 있어요. 저희는 그 다음 이야기를 이어 드려요."]','[{"phrase": "has had a life before → 누군가의 손을 한 번 거쳤어요", "why": "''전에 삶을 가졌다''는 어색해요. 중고 물건이라는 뜻을 한국어 관용 표현으로 살려요."}, {"phrase": "a second one → 두 번째 주인, 두 번째 삶", "why": "one은 앞의 a life를 받아요. 카피에서는 ''두 번째 삶''이나 ''주인''으로 대구를 살려요."}, {"phrase": "We just make sure ~ → 저희는 ~할 뿐이에요", "why": "''확실히 한다''로 옮기면 딱딱해요. just의 겸손한 말투를 ''~할 뿐이에요''로 옮겨요."}]'),
  ('dr-20261012-ek-b1','수치가 나오면 다음 주에 이 건을 다시 논의하죠.','["숫자가 나오면 다음 주에 다시 이야기해요.", "다음 주에 자료가 나오는 대로 이 안건을 다시 보죠."]','[{"phrase": "circle back on → ~을 다시 논의하다", "why": "''원을 그리며 돌아오다''가 아니에요. 회의에서 미뤄 둔 안건을 나중에 다시 다루자는 말이에요."}, {"phrase": "once we have the numbers → 수치가 나오면", "why": "''우리가 숫자를 가지면''은 번역투예요. once는 ''~하면, ~하는 대로''로 옮겨요."}, {"phrase": "Let''s ~ → ~하죠", "why": "회의에서 팀장이 정리하는 말투예요. ''~합시다''보다 ''~하죠''가 부드러워요."}]');
insert into public.weekly_reports (author, week_of, body) values
  ((select email from public.members where display_name='희주'),'2026-10-12','지난 한 주는 번역 연습을 쉬어 갔어요. 바쁜 주였나 봐요.
지난번 리포트의 자주 틀린 것 3가지를 다시 짚어 볼게요.
1. 원문 둘째 문장 빠뜨리기 → 짧은 카피라도 두 문장을 끝까지 옮겨요.
2. date → plans. 친구와의 약속은 plans예요.
3. Family meeting → a family gathering. 가족 모임은 gathering이에요.
좋아진 점: 9월 28일 이후로 오답 노트에 새로 쌓인 표현이 없어요.
이번 주 번역 연습에 나를 위한 문장 1개를 넣었어요(주말 약속 문자, plans·housewarming).
한 문장만 해도 괜찮아요. 🔁 다시 도전으로 지난 문장 하나를 다시 옮겨 보는 것부터 시작해 보세요.'),
  ((select email from public.members where display_name='혜림'),'2026-10-12','지난 한 주 번역 연습 5문장을 내고, 🔁 다시 도전을 7번 했어요. 피드백도 2번 요청했어요.
자주 틀린 것 3가지예요.
1. from 11 a.m. → until 11 a.m. (2번 나왔어요) 기한·끝나는 시점은 until이에요. 이번 주에는 until과 by를 구분하는 문장을 넣었어요.
2. readed → read. read는 과거형도 read예요(발음만 ''레드'').
3. 800 pieces → 800 books. 셀 수 있는 물건은 pieces를 붙이지 않고 그 명사를 바로 복수로 써요.
좋아진 점: 다시 도전을 가장 먼저, 가장 많이 해 봤어요. 같은 문장을 다시 옮기며 스스로 고친 흔적이 보여요.
이번 주 번역 연습에 나를 위한 문장 1개를 넣었어요(견적 회신 기한, until과 by).
책 맡기기(consignment)는 복습 단어에 넣었어요. 오늘의 복습에서 다시 만나요.')
on conflict (author, week_of) do nothing;
insert into public.copy_briefs (id, week, title, product, target, tone, rules, sort) values
  ('cb-20261012-1','2026-10-12','Saltmoss · 무향 선크림','향을 전혀 넣지 않은 데일리 선크림. SPF 50, 끈적임 없이 바로 스며들어요. 50ml 18달러.','향 때문에 선크림을 거르던 예민한 피부의 직장인','차분하게. 없는 것(향)을 장점으로.','매장 쇼윈도 문구 6단어 이하. gentle, lightweight는 쓰지 않아요.',1),
  ('cb-20261012-2','2026-10-12','Inkburrow · 어린이 그림책 구독','매달 아이 나이에 맞춘 그림책 두 권을 집으로 보내 줘요. 다 읽은 책은 돌려보내면 다음 달 요금이 2달러 내려가요. 한 달 15달러.','잠자리 책 고르기가 버거운 3~6세 아이의 부모','따뜻하게. 잠들기 전 한 장면으로.','유튜브 6초 광고 자막 2줄, 각 줄 6단어 이하. magical, adventure는 쓰지 않아요.',2),
  ('cb-20261012-3','2026-10-12','Hollowbay · 작은 동네 코워킹','책상 12개뿐인 동네 코워킹. 하루권 12달러, 커피와 전화 부스 포함. 집에서 걸어서 10분 거리의 사무실.','집에서 일하다 지친 프리랜서','담백하게. 숫자(책상 12개)를 살려서.','웹사이트 상품 페이지 헤드라인 8단어 이하 + 설명 1줄(15단어 이하). community, vibe는 쓰지 않아요.',3)
on conflict (id) do nothing;
insert into public.terms (id, word, pair, meaning, examples, register, domain, lang, added_by) values
  ('t-are-we-still-on','Are we still on (for ~)?','약속 아직 유효하지?, 그대로 만나는 거지?','이미 잡은 약속이 그대로인지 묻는 구어. ''아직 위에 있어?''가 아니에요.','[{"s":"Are we still on for Saturday?","t":"토요일 약속 아직 유효하지?"},{"s":"Are we still on for coffee tomorrow?","t":"내일 커피 마시는 거 그대로지?"},{"s":"Just checking — are we still on for 7?","t":"혹시나 해서, 7시 약속 그대로 맞지?"},{"s":"Sorry, something came up. We''re not on for tonight after all.","t":"미안, 일이 생겨서 오늘 저녁은 결국 못 만나겠어."}]'::jsonb,'구어','일반','en',null),
  ('t-housewarming','housewarming','집들이','새집에 이사 가서 사람들을 초대하는 모임. house party(그냥 집에서 여는 파티)와 달라요.','[{"s":"I''ve got my cousin''s housewarming that evening.","t":"그날 저녁엔 사촌 집들이가 있어."},{"s":"We''re having a housewarming next Saturday. Can you come?","t":"다음 주 토요일에 집들이해. 올 수 있어?"},{"s":"What should I bring as a housewarming gift?","t":"집들이 선물로 뭘 가져가야 할까?"},{"s":"They finally threw a housewarming three months after moving in.","t":"이사하고 석 달 만에 드디어 집들이를 했어."}]'::jsonb,'구어','일반','en',null),
  ('t-circle-back','circle back (on ~)','~을 나중에 다시 논의하다','회의에서 미뤄 둔 안건을 나중에 다시 다루자는 말. ''원을 그리다''가 아니에요.','[{"s":"Let''s circle back on this next week once we have the numbers.","t":"수치가 나오면 다음 주에 이 건을 다시 논의하죠."},{"s":"Can we circle back to the budget at the end?","t":"예산 얘기는 마지막에 다시 할까요?"},{"s":"I''ll circle back with you after I talk to the client.","t":"고객과 이야기해 보고 다시 연락드릴게요."},{"s":"We never circled back on the logo question.","t":"로고 문제는 결국 다시 논의를 못 했네요."}]'::jsonb,'전문','비즈니스·IR','en',null),
  ('t-consignment','consignment','위탁 판매, 책 맡기기','남의 물건을 맡아 대신 팔고 수익을 나누는 거래. book keeping이라고 하면 ''장부 정리''가 돼요.','[{"s":"A neighborhood bookstore has launched a book consignment service.","t":"한 동네 서점이 ''책 맡기기'' 서비스를 시작했다."},{"s":"The shop sells vintage clothes on consignment.","t":"그 가게는 빈티지 옷을 위탁 판매해요."},{"s":"We take a 30% cut on consignment sales.","t":"위탁 판매 금액의 30%를 수수료로 받아요."},{"s":"I left my old guitar at a consignment store.","t":"쓰던 기타를 위탁 판매점에 맡겼어."}]'::jsonb,'문어','비즈니스·IR','en',null),
  ('t-roll-out','roll out','(새 제도·서비스를) 차례로 도입하다, 출시하다','새 제도나 제품을 여러 곳에 순서대로 시행할 때 기사·업무에서 자주 써요. ''굴려 내보내다''가 아니에요.','[{"s":"Major performance venues are rolling out \"last-ten-minute tickets.\"","t":"주요 공연장들이 ''마지막 10분 티켓''을 도입하고 있다."},{"s":"The update will roll out to all users next week.","t":"업데이트는 다음 주에 모든 사용자에게 순차 적용됩니다."},{"s":"We''re rolling out the new menu in five stores first.","t":"새 메뉴는 매장 다섯 곳에 먼저 선보여요."},{"s":"The rollout was delayed by a month.","t":"도입이 한 달 미뤄졌다."}]'::jsonb,'문어','비즈니스·IR','en',null),
  ('t-bichi','비치되어 있습니다','있습니다 → 놓여 있습니다 → 비치되어 있습니다','is/are provided (안내문에서 물건을 놓아 두었다고 알릴 때)','[{"s":"수건은 입구에 비치되어 있습니다.","t":"Towels are provided at the entrance."},{"s":"객실에 생수 두 병이 비치되어 있습니다.","t":"Two bottles of water are provided in your room."},{"s":"안내 책자는 1층 로비에 비치되어 있습니다.","t":"Brochures are available in the first-floor lobby."},{"s":"손 소독제가 각 층 엘리베이터 앞에 비치되어 있습니다.","t":"Hand sanitizer is available by the elevators on every floor."}]'::jsonb,'문어','공문·행정','ko',null),
  ('t-hyujang','휴장합니다','쉽니다 → 운영을 쉽니다 → 휴장합니다','will be closed (수영장·공원·시장 같은 시설이 쉰다고 알릴 때)','[{"s":"수영장은 시설 점검으로 10월 12일부터 14일까지 휴장합니다.","t":"The pool will be closed for maintenance from October 12 to 14."},{"s":"추석 연휴 기간에는 전통시장이 휴장합니다.","t":"The traditional market will be closed during the Chuseok holiday."},{"s":"매주 월요일은 정기 휴장일입니다.","t":"We are closed every Monday."},{"s":"우천 시 야외 놀이터는 휴장합니다.","t":"The outdoor playground is closed in case of rain."}]'::jsonb,'문어','공문·행정','ko',null)
on conflict (id) do nothing;
commit;
