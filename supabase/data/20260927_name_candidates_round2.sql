-- 이름 후보 2차 10개 (건의 "이름 후보를 더 추천해 주세요", 2026-09-27). 좋아요 받은 후보의 방향을 이어서 골랐어요.
insert into name_candidates (id, name, gloss, sort, shown, added_by) values
('nc-31','말끗','말 + 한 끗',31,true,null),('nc-32','결맛','말의 결 + 말의 맛',32,true,null),
('nc-33','결결이','결마다, 하나하나',33,true,null),('nc-34','두말살롱','두 언어 + 살롱',34,true,null),
('nc-35','옮김살롱','번역(옮김) + 살롱',35,true,null),('nc-36','한끗번역소','한 끗 차이를 다듬는 번역소',36,true,null),
('nc-37','오역수사대','오역을 잡는 팀',37,true,null),('nc-38','Grain & Tongue','결 + 말(혀)',38,true,null),
('nc-39','Flip & Fit','뒤집고, 맞추고',39,true,null),('nc-40','Both Ways','양방향으로',40,true,null)
on conflict (id) do nothing;  -- 이유(why)는 DB에만 있어요
