-- 교차번역 원문 6개의 추천 표현. Claude Code가 직접 작성 (AI API 호출 없음).
-- 원문 id 가 DB마다 다를 수 있어서 제목으로 찾는다.
insert into public.session_models (session_id, best, alternatives, notes)
select s.id, m.best, m.alternatives::jsonb, m.notes::jsonb
from (values
('일상 · 약속 바꾸기',
 'Would it be okay to move our Saturday plans to Sunday? Something came up with my family.',
 '["Could we push our plans from Saturday to Sunday? A family thing just came up.","Mind if we switch this Saturday to Sunday? I''ve got a last-minute family get-together."]',
 '[{"phrase":"약속 → plans","why":"친구와의 약속은 promise가 아니라 plans예요. promise는 ''꼭 하겠다''는 다짐이에요."},{"phrase":"갑자기 ~이 생겼어요 → something came up","why":"급한 일이 생겼을 때 쓰는 관용 표현이에요. suddenly를 넣지 않아도 갑작스러운 느낌이 있어요."},{"phrase":"옮기다 → move / push / switch","why":"일정을 옮길 때 move, 뒤로 미룰 때 push (back), 서로 바꿀 때 switch를 써요."}]'),
('안내문 · 카페 휴무',
 '이번 주 월요일은 직원 교육으로 쉽니다. 화요일 오전 8시에 다시 만나요!',
 '["이번 주 월요일은 직원 교육으로 하루 휴무합니다. 화요일 아침 8시에 뵐게요!","월요일은 직원 교육 관계로 문을 닫습니다. 화요일 오전 8시에 다시 문을 열어요!"]',
 '[{"phrase":"We''re closed → 쉽니다 / 휴무합니다","why":"안내문에서 ''우리는 닫혀 있습니다''는 어색해요. 가게 안내문은 주어를 빼고 ''쉽니다/휴무합니다''라고 써요."},{"phrase":"See you again → 다시 만나요 / 뵐게요","why":"카페 분위기에 따라 친근하게(만나요) 또는 공손하게(뵐게요) 골라요. 격을 정하는 연습이 돼요."}]'),
('동네 소식 · 도서관',
 'Starting next month, the district library will stay open until 10 p.m. on weekdays. The change comes in response to requests from residents who want to borrow books or study after work.',
 '["The public library will extend its weekday hours to 10 p.m. from next month, following requests from residents who want to borrow books or study after work.","From next month, the district library will be open until 10 p.m. on weekdays, responding to residents'' calls for access after work hours."]',
 '[{"phrase":"구립 도서관 → district / public library","why":"구(區)는 영어에서 district예요. 독자가 외국인이면 public library가 더 쉽게 읽혀요."},{"phrase":"밤 10시까지 문을 연다 → stay open until 10 p.m.","why":"open until만 쓰면 문을 여는 시각처럼 읽힐 수 있어요. 운영 시간 연장은 stay open이나 extend its hours로 써요."},{"phrase":"~을 반영한 것이다 → comes in response to / following","why":"기사체 ''~한 것이다''는 영어에 그대로 옮길 형태가 없어요. 이유를 설명하는 구문으로 바꿔요."}]'),
('생활 기사 · 건강',
 '식후에 잠깐 걷기만 해도 혈당을 안정적으로 유지하는 데 도움이 된다는 연구 결과가 나왔다. 연구진은 단 10분만 걸어도 효과가 있다고 말한다.',
 '["새로운 연구에 따르면 식사 후 짧게 산책하면 혈당이 안정되는 데 도움이 된다. 연구진은 10분만 걸어도 차이가 생긴다고 설명했다.","밥 먹고 잠깐 걷는 것만으로도 혈당 관리에 도움이 된다는 연구가 나왔다. 연구진에 따르면 10분이면 충분하다."]',
 '[{"phrase":"A new study suggests that → ~라는 연구 결과가 나왔다","why":"''새 연구가 제안한다''는 번역투예요. 한국어 기사는 결과를 먼저 말하고 ''연구 결과가 나왔다''로 맺어요."},{"phrase":"keep blood sugar levels steady → 혈당을 안정적으로 유지하다","why":"steady는 ''꾸준한''이 아니라 ''안정적인''이에요. levels는 옮기지 않아도 돼요."},{"phrase":"make a difference → 효과가 있다","why":"''차이를 만든다''는 직역이에요. 건강 기사에서는 ''효과가 있다/도움이 된다''가 자연스러워요."}]'),
('대역 기사 · 경제 (예시 원문)',
 'Major South Korean companies said they will scale back hiring in the second half of the year compared with last year. As external uncertainties drag on, they plan to put new investment on hold and focus on managing their workforce more efficiently. Experts expect employment conditions for young people to remain difficult for the time being.',
 '["Leading Korean firms announced plans to hire fewer people in the second half than a year earlier, shelving new investments and prioritizing workforce efficiency amid prolonged external uncertainty. Experts say job prospects for young people are unlikely to improve anytime soon."]',
 '[{"phrase":"국내 주요 기업 → major South Korean companies","why":"''국내''는 한국 독자 기준이에요. 영어 기사에서는 domestic보다 나라 이름을 밝혀요."},{"phrase":"대외 불확실성이 장기화되면서 → as external uncertainties drag on","why":"장기화되다는 drag on, persist, prolonged로 옮겨요. 이유를 나타내는 ''~면서''는 as나 amid로 받아요."},{"phrase":"~에 방점을 두다 → focus on / prioritize","why":"''점을 찍다''를 옮기지 않고 뜻(중점을 두다)만 살려요."},{"phrase":"내다봤다 → expect / forecast","why":"기사 끝 ''~로 내다봤다''는 전망을 전하는 말이에요. said보다 expect가 뜻이 정확해요."}]'),
('대역 기사 · 사회 (예시 원문)',
 '시의회가 비어 있는 사무용 건물 세 곳을 저렴한 주택으로 바꾸는 시범 사업을 승인했다. 시 관계자들은 이 사업으로 도심 지역의 임대료 부담이 줄어들 것으로 기대한다고 밝혔지만, 일각에서는 예산이 리모델링 비용을 감당하기에 충분할지 의문을 제기했다.',
 '["시의회는 쓰지 않는 사무 건물 3곳을 서민 주택으로 전환하는 시범 사업을 승인했다. 시는 이번 사업이 도심 임대료 상승 압박을 덜어 줄 것으로 보고 있으나, 비판 측은 예산으로 개보수 비용을 충당할 수 있을지 의문을 나타냈다."]',
 '[{"phrase":"affordable housing → 저렴한 주택 / 서민 주택","why":"정책 용어라 맥락에 맞게 골라요. ''부담 가능한 주택''은 학술 용어에 가까워요."},{"phrase":"ease pressure on rents → 임대료 부담을 덜다","why":"''압력을 완화하다''는 직역이에요. 한국어 기사에서는 ''부담을 덜다/상승 압박을 줄이다''를 써요."},{"phrase":"critics → 일각에서는 / 비판론자들은","why":"한국어 기사는 ''비평가들''보다 ''일각에서는''이나 ''비판 측은''이라고 써요."},{"phrase":"Officials said → 시 관계자들은 ~고 밝혔다","why":"''공무원들이 말했다''보다 ''관계자들은 ~고 밝혔다''가 기사체예요."}]')
) as m(title, best, alternatives, notes)
join public.sessions s on s.title = m.title
on conflict (session_id) do nothing;
