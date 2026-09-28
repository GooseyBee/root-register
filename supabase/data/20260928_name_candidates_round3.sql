-- 이름 후보 3차 (2026-09-28): 다른 곳에서 쓰지 않는 이름만. 웹 검색으로 같은 이름의 앱·서비스가 없는지 확인했어요.
-- 확인 결과 사용 중: CROSSLINGO(번역 회사), FLIPTALK(통역·학습 앱 여러 개), FlipLingo, LingoSwap → 후보에서 제외하거나 ⚠ 표시.
-- 사용처를 찾지 못함: 말끗, 결맛, 결결이, 두말살롱, 옮김살롱, Grain & Tongue(이미 후보) + 아래 4개.
insert into name_candidates (id, name, gloss, sort, shown, added_by) values
('nc-41','Crossgrain','결을 가로질러',41,true,null),
('nc-42','Flipgrain','뒤집고, 결을 살리고',42,true,null),
('nc-43','Crossfold','교차 + 접기',43,true,null),
('nc-44','Tonguebridge','두 언어 사이의 다리',44,true,null)
on conflict (id) do nothing;  -- 이유(why)와 ⚠ 표시는 DB에만 있어요
