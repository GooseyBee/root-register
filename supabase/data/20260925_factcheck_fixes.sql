-- 팩트체크(웹 리서치) 결과 반영: 번역 연습 추천 표현 5건 수정
update public.drill_models set
  best = 'Your skin will feel the difference first.',
  alternatives = '["Feel the difference from the very first use.","Your skin knows the difference."]',
  notes = '[{"phrase":"feel the difference","why":"스킨케어 광고의 정형 표현이에요(\"Feel the difference\"). 원래 추천한 Your skin will notice first는 뜻은 통해도 실제 카피에서는 잘 안 쓰는 조합이라 바꿨어요."},{"phrase":"from the very first use","why":"''처음부터 바로''라는 즉각 효과를 강조할 때 붙여요."}]'
where drill_id = 'dr-m2';

update public.drill_models set
  best = 'I''ve attached the materials you requested for your review.',
  alternatives = '["Please find attached the materials you requested.","Attached are the documents you asked for. Let me know if you have any questions."]',
  notes = '[{"phrase":"I''ve attached","why":"요즘 영어권 비즈니스 메일에서는 가장 무난한 표현이에요."},{"phrase":"Please find attached","why":"여전히 쓰이지만 딱딱하고 오래된 문구로 보는 가이드가 많아요. 아주 격식 있는 상대에게만 쓰세요."},{"phrase":"for your review","why":"''검토 부탁드립니다''를 짧게 덧붙이는 방법이에요."}]'
where drill_id = 'dr-b2';

update public.drill_models set
  best = 'Could we pay separately? Do you take cards?',
  alternatives = '["Can we split the bill? Can I pay by card?"]',
  notes = '[{"phrase":"pay separately / split the bill","why":"separately는 각자 먹은 것을 내는 것, split the bill은 금액을 나눠 내는 뉘앙스예요."},{"phrase":"Do you take cards? / Can I pay by card?","why":"둘 다 어디서나 통해요. Do you take card?(단수)는 영국·호주에서 흔한 구어예요. 미국에서는 Do you take credit cards?도 많이 써요."}]'
where drill_id = 'dr-t4';

update public.drill_models set
  best = 'My bag didn''t come out on the carousel. Where do I report it?',
  alternatives = '["My luggage hasn''t arrived. Where''s the baggage service office?"]',
  notes = '[{"phrase":"didn''t come out on the carousel","why":"수하물 벨트(carousel)에서 안 나왔다는 상황을 정확히 말해요."},{"phrase":"baggage service office","why":"공항·항공사에서 분실 수하물을 접수하는 곳의 실제 이름이에요. lost baggage desk보다 정확해요."},{"phrase":"luggage / bag","why":"luggage는 셀 수 없는 명사라서 가방 하나는 my bag이 자연스러워요."}]'
where drill_id = 'dr-t5';

update public.drill_models set
  alternatives = '["Is tomorrow morning''s tour fully booked?"]'
where drill_id = 'dr-t6';
