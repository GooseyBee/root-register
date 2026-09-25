-- 영어 예문 36개에 설명(note)과 어려운 단어(words)를 붙인다. 오늘의 문장이 이 값을 그대로 보여 준다.
-- notes 배열의 순서 = terms.examples 배열의 순서. AI 호출 없이 미리 써 둔 데이터다.
with n(id, notes) as (values
('t-advertise', '[
 {"note":"advertise는 목적어 없이 ''광고를 하다''로도 쓰여요. heavily는 ''많이, 집중적으로''라는 뜻으로 advertise, invest, rely 같은 동사와 잘 어울려요.","words":[{"word":"heavily","meaning":"많이, 집중적으로"},{"word":"holiday season","meaning":"연말 시즌 (미국은 추수감사절부터 새해까지)"}]},
 {"note":"position은 채용 맥락에서 ''자리, 직책''이고, advertise는 ''공고하다''예요. 채용 공고는 수동태로 자주 써요.","words":[{"word":"position","meaning":"(채용) 자리, 직책"},{"word":"job board","meaning":"구인 게시판, 구인 사이트"}]},
 {"note":"여기서 advertise는 광고보다 ''널리 알리다''에 가까워요. 부정문이라 ''굳이 알리지 않았다''는 뉘앙스가 생겨요.","words":[{"word":"price increase","meaning":"가격 인상 (price hike는 더 기사체·구어)"}]},
 {"note":"advertised as ~는 ''~라고 광고되는''이에요. not always는 부분 부정으로 ''항상 ~인 것은 아니다''라는 뜻이에요.","words":[{"word":"advertised as","meaning":"~라고 광고되는"},{"word":"not always","meaning":"항상 ~인 것은 아닌 (부분 부정)"}]}
]'::jsonb),
('t-ascertain', '[
 {"note":"ascertain은 조사나 확인을 거쳐 사실을 확정한다는 격식 있는 동사예요. 기사에서 find out 대신 자주 써요.","words":[{"word":"ascertain","meaning":"(조사로) 확인하다, 규명하다"},{"word":"cause","meaning":"원인"}]},
 {"note":"It is difficult to ~는 가주어 구문이에요. affected는 재난 보도에서 ''피해를 입은''이라는 뜻으로 쓰여요.","words":[{"word":"affected","meaning":"영향을 받은, 피해를 입은"}]},
 {"note":"ascertain whether ~는 ''~인지 확인하다''예요. 법률, 계약 맥락의 전형적인 표현이에요.","words":[{"word":"valid","meaning":"유효한"},{"word":"contract","meaning":"계약, 계약서"}]},
 {"note":"was unable to는 couldn''t보다 격식 있는 표현이라 보고서체에 잘 어울려요.","words":[{"word":"committee","meaning":"위원회"},{"word":"be unable to","meaning":"~할 수 없다 (격식)"}]}
]'::jsonb),
('t-credible', '[
 {"note":"credible evidence는 ''믿을 만한 증거''로 뉴스와 법률에서 굳어진 조합이에요. support the claim은 ''주장을 뒷받침하다''예요.","words":[{"word":"evidence","meaning":"증거 (셀 수 없는 명사)"},{"word":"claim","meaning":"주장"}]},
 {"note":"credible plan은 실현 가능성이 있어 믿음이 가는 계획이에요. 투자자나 신용평가 맥락에서 자주 나와요.","words":[{"word":"debt","meaning":"부채, 빚"},{"word":"reduce","meaning":"줄이다"}]},
 {"note":"make + 목적어 + 형용사 구조예요. 카피에서 신뢰를 높이는 장치를 설명할 때 그대로 쓸 수 있어요.","words":[{"word":"review","meaning":"후기, 리뷰"},{"word":"promise","meaning":"약속 (브랜드가 내세우는 가치)"}]},
 {"note":"see A as B는 ''A를 B로 보다''예요. credible challenger는 ''승산 있는 도전자''로 선거나 시장 경쟁 기사에 자주 나와요.","words":[{"word":"analyst","meaning":"분석가"},{"word":"challenger","meaning":"도전자"}]}
]'::jsonb),
('t-ease-pressure', '[
 {"note":"is expected to는 기사에서 전망을 전할 때 쓰는 표현이에요. ease pressure on + 명사를 한 덩어리로 익혀 두세요.","words":[{"word":"ease","meaning":"완화하다, 덜다"},{"word":"rents","meaning":"임대료 (복수형으로 전반적인 임대료 수준)"}]},
 {"note":"cut rates는 ''금리를 인하하다''의 기사체예요. households는 경제 기사에서 ''가계''로 옮겨요.","words":[{"word":"central bank","meaning":"중앙은행"},{"word":"household","meaning":"가계, 가구"}]},
 {"note":"would는 가정했을 때의 결과를 말해요. night shift는 ''야간 근무, 야간조''예요.","words":[{"word":"shift","meaning":"교대 근무, 근무조"},{"word":"hire","meaning":"고용하다"}]},
 {"note":"여기서 should는 의무가 아니라 ''~할 것으로 보인다''는 예상이에요. 교통 기사에서 흔한 용법이에요.","words":[{"word":"should (예상)","meaning":"~할 것으로 보인다"}]}
]'::jsonb),
('t-induce', '[
 {"note":"induce는 원인이 결과를 불러온다는 뜻의 격식 동사예요. 경제 기사에서 lead to, encourage와 바꿔 쓸 수 있어요.","words":[{"word":"interest rate","meaning":"금리"},{"word":"borrowing","meaning":"차입, 대출"}]},
 {"note":"induce + 사람 + to 부정사는 ''~가 …하도록 유도하다''예요. 마케팅 문서에 그대로 쓸 수 있는 구조예요.","words":[{"word":"first-time buyer","meaning":"첫 구매자"},{"word":"sign up","meaning":"가입하다"}]},
 {"note":"Nothing could induce ~는 ''어떤 것으로도 ~하게 만들 수 없었다''는 강한 부정이에요. 문어체 느낌이 나요.","words":[{"word":"change one''s mind","meaning":"마음을 바꾸다"}]},
 {"note":"의학 맥락의 induce는 ''유발하다''예요. 약 설명서의 부작용 문장에 자주 나와요.","words":[{"word":"drowsiness","meaning":"졸음"},{"word":"patient","meaning":"환자"}]}
]'::jsonb),
('t-inspire', '[
 {"note":"a new generation of ~는 ''새로운 세대의 ~''예요. 브랜드 캠페인의 성과를 말할 때 자주 써요.","words":[{"word":"campaign","meaning":"(광고, 사회) 캠페인"},{"word":"generation","meaning":"세대"}]},
 {"note":"inspire + 사람 + to 부정사는 ''~가 …하도록 자극하다''예요. rethink는 ''다시 생각하다, 재고하다''예요.","words":[{"word":"rethink","meaning":"재고하다"}]},
 {"note":"be inspired by ~는 ''~에서 영감을 받다''예요. 디자인이나 제품 설명에 자주 쓰여요.","words":[{"word":"architecture","meaning":"건축, 건축 양식"},{"word":"traditional","meaning":"전통의"}]},
 {"note":"not just A; B로 대비를 줬어요. 세미콜론은 밀접한 두 문장을 잇는 부호예요. copy는 ''광고 문안''이에요.","words":[{"word":"copy","meaning":"광고 문안, 카피 (셀 수 없는 명사)"},{"word":"inform","meaning":"정보를 주다, 알리다"}]}
]'::jsonb),
('t-numerous', '[
 {"note":"numerous는 many보다 격식 있는 표현이에요. 셀 수 있는 복수 명사 앞에만 써요.","words":[{"word":"proposal","meaning":"제안, 제안서"},{"word":"complaint","meaning":"불만, 민원"}]},
 {"note":"link A to B는 ''A와 B의 연관성을 밝히다''예요. 연구 결과를 전하는 기사의 전형적인 문장이에요.","words":[{"word":"study","meaning":"연구"},{"word":"link A to B","meaning":"A를 B와 연결 짓다"}]},
 {"note":"현재완료 has won은 지금까지의 경력을 말해요. win an award는 ''상을 받다''의 기본 조합이에요.","words":[{"word":"award","meaning":"상"}]},
 {"note":"on numerous occasions는 ''여러 차례''라는 격식 표현이에요. board는 ''이사회''예요.","words":[{"word":"occasion","meaning":"경우, 때"},{"word":"board","meaning":"이사회"}]}
]'::jsonb),
('t-obtain', '[
 {"note":"obtain은 절차를 밟아 얻는다는 뉘앙스가 있어 비자, 허가, 승인과 잘 어울려요.","words":[{"word":"applicant","meaning":"신청자, 지원자"},{"word":"enter","meaning":"입국하다, 들어가다"}]},
 {"note":"학술문에서는 data를 복수로 보고 were를 쓰기도 해요. 일상에서는 was도 흔해요.","words":[{"word":"data","meaning":"자료, 데이터"},{"word":"survey","meaning":"(설문) 조사"}]},
 {"note":"obtain approval from ~는 ''~의 승인을 받다''예요. regulators는 기사에서 ''규제 당국''으로 옮겨요.","words":[{"word":"approval","meaning":"승인"},{"word":"regulator","meaning":"규제 기관"}]},
 {"note":"안내문에서 쓰는 수동태 표현이에요. 한국어로는 ''확인하실 수 있습니다''처럼 능동으로 옮기는 게 자연스러워요.","words":[{"word":"further","meaning":"추가의, 더 자세한"}]}
]'::jsonb),
('t-perspective', '[
 {"note":"from A''s perspective는 ''A의 입장에서 보면''이에요. from the consumer''s point of view와 같은 뜻이에요.","words":[{"word":"consumer","meaning":"소비자"}]},
 {"note":"perspective on ~는 ''~에 대한 시각''이에요. 전치사 on을 함께 기억하세요.","words":[{"word":"abroad","meaning":"해외에서"},{"word":"perspective on","meaning":"~에 대한 관점"}]},
 {"note":"put ~ into perspective는 ''~을 큰 맥락에서 보다, 제대로 가늠하다''라는 관용 표현이에요.","words":[{"word":"put into perspective","meaning":"맥락 속에서 보다 (관용구)"}]},
 {"note":"examine은 ''면밀히 살펴보다''라는 격식 동사예요. 보고서나 논문을 소개하는 문장에 잘 맞아요.","words":[{"word":"examine","meaning":"검토하다, 살펴보다"},{"word":"historical","meaning":"역사적인"}]}
]'::jsonb)
)
update public.terms t
set examples = (
  select jsonb_agg(e.v || coalesce(n.notes -> (e.i::int - 1), '{}'::jsonb) order by e.i)
  from jsonb_array_elements(t.examples) with ordinality as e(v, i)
)
from n
where t.id = n.id;
