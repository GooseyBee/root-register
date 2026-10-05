// assist: 피드백 자동 답변(Gemini 무료 API) + 웹 푸시 알림.
// 앱(docs/index.html)이 로그인한 사용자 토큰으로 부른다. 멤버만 쓸 수 있다.
//   { action: "feedback", id }        → 내 피드백 요청에 Gemini가 설명을 달고, 오답 노트를 갱신하고, 푸시를 보낸다
//   { action: "request-posted", id }  → 새 건의가 올라왔다고 관리자(희주)에게 푸시
//   { action: "test-push", endpoint? } → 테스트 푸시. endpoint가 있으면 그 기기로만(버튼을 누른 기기), 없으면 내 모든 기기로
//   { action: "comment-reply", id }   → 내 답장을 원래 코멘트 쓴 사람에게 푸시
//   { action: "claude-requested", id } → Claude 정밀 검토 요청을 희주에게 푸시(루틴이 하루 3번 처리, 급하면 희주가 직접)
//   { action: "retry-compare", id }   → 다시 도전(drill_retries) 한 차수를 앞 번역들과 비교해 Gemini가 분석(analysis)을 단다
// DB 트리거(pg_net)가 x-hook-secret 헤더로 부른다:
//   { action: "request-done", id }    → 건의가 완료되면 올린 사람에게 푸시
//   { action: "content-added", kind, n, enkr, kren } → 새 번역 연습 문장·교차번역 원문이 들어오면 모두에게 푸시
//   { action: "claude-answered", id } → Claude 정밀 검토가 달리면 요청한 사람에게 푸시
//   { action: "report-added", id }    → 주간 리포트가 들어오면 그 사람에게 푸시
//   { action: "feedback-retry", id } → 과부하로 실패한 피드백 요청을 10분마다 다시 시도(pg_cron, 최대 3번)
//   { action: "session-saved", session_id, author } → 교차번역 번역을 처음 저장하면 아직 안 한 사람에게 푸시
// 알림 종류(kind)마다 notify_prefs.off에 들어 있는 사람은 휴대폰 알림에서 뺀다(테스트 알림은 예외).
// 인증: 사용자 호출은 함수 안에서 토큰을 확인한다(getUser + members). 트리거 호출은 JWT가 없어서
//       배포할 때 verify_jwt=false 로 두고, hook_secret 으로 확인한다.
// 비밀값: GEMINI_API_KEY 는 Edge Function 시크릿(없으면 private.app_secrets 의 gemini_api_key),
//         VAPID 키는 private.app_secrets 에서 읽는다. 요금: Google 프로젝트에 결제를 연결하지 않으면 무료 한도를 넘어도 과금되지 않고 429 로 실패한다.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SITE = "https://root-register.vercel.app";
// 무료 티어 모델을 차례로 시도한다. GEMINI_MODEL 시크릿이 있으면 그것부터.
// 없는 모델(404)은 바로 건너뛰고, 과부하·한도(503/429/500)면 2초 쉬고 한 번 더, 그래도 안 되면 다음 모델로.
// 무료 한도와 혼잡은 모델마다 따로라서, 하나가 붐벼도 다른 모델이 받아 줄 때가 많다.
const MODELS = [Deno.env.get("GEMINI_MODEL"), "gemini-3-flash", "gemini-3-flash-preview", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.0-flash"].filter(Boolean) as string[];
const MAX_TRIES = 3;  // 사용자 요청 1번 + 10분마다 자동 재시도 2번(pg_cron). 마지막까지 실패해야 희주에게 알린다

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

type Member = { email: string; display_name: string; is_admin: boolean };
type Mistake = { wrong: string; better: string; why: string };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

  const hook = req.headers.get("x-hook-secret");
  if (hook) {
    const expected = await secret(db, "hook_secret");
    if (!expected || hook !== expected) return json({ error: "bad hook" }, 401);
    const hb = await req.json().catch(() => ({}));
    if (hb.action === "request-done") return json(await requestDone(db, String(hb.id || "")));
    if (hb.action === "content-added") return json(await contentAdded(db, hb));
    if (hb.action === "claude-answered") return json(await claudeAnswered(db, String(hb.id || "")));
    if (hb.action === "report-added") return json(await reportAdded(db, String(hb.id || "")));
    if (hb.action === "feedback-retry") return json(await feedbackRetry(db, String(hb.id || "")));
    if (hb.action === "session-saved") return json(await sessionSaved(db, String(hb.session_id || ""), String(hb.author || "")));
    return json({ error: "unknown hook" }, 400);
  }

  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  const { data: u } = await db.auth.getUser(token);
  const email = u?.user?.email?.toLowerCase();
  if (!email) return json({ error: "로그인이 필요해요." }, 401);
  const { data: me } = await db.from("members").select("email,display_name,is_admin").eq("email", email).maybeSingle();
  if (!me) return json({ error: "멤버가 아니에요." }, 403);

  const body = await req.json().catch(() => ({}));
  try {
    if (body.action === "feedback") return json(await feedback(db, me as Member, String(body.id || "")));
    if (body.action === "request-posted") return json(await requestPosted(db, me as Member, String(body.id || "")));
    if (body.action === "comment-reply") return json(await commentReply(db, me as Member, String(body.id || "")));
    if (body.action === "claude-requested") return json(await claudeRequested(db, me as Member, String(body.id || "")));
    if (body.action === "retry-compare") return json(await retryCompare(db, me as Member, String(body.id || "")));
    if (body.action === "test-push") {
      const n = await pushTo(db, "", [email], { title: "알림 테스트", body: "이 기기로 알림이 잘 와요.", url: "/" }, body.endpoint ? String(body.endpoint) : undefined);
      return json({ ok: true, sent: n });
    }
    return json({ error: "unknown action" }, 400);
  } catch (e) {
    return json({ error: String((e as Error).message || e) }, 500);
  }
});

async function secret(db: SupabaseClient, name: string): Promise<string> {
  const { data } = await db.rpc("app_secret", { n: name });
  return (data as string) || "";
}

// ---------- 피드백 ----------
async function feedback(db: SupabaseClient, me: Member, id: string) {
  const { data: f } = await db.from("feedback_requests").select("*").eq("id", id).eq("author", me.email).maybeSingle();
  if (!f) return { status: "missing" };
  if (f.answered_at) return { status: "answered" };

  const t = await loadTarget(db, f.target_type, f.target_id, me.email);
  if (!t || !t.mine) return await fail(db, f, me, "제출한 번역을 찾지 못했어요.");

  const key = Deno.env.get("GEMINI_API_KEY") || (await secret(db, "gemini_api_key"));
  if (!key) return await fail(db, f, me, "Gemini API 키가 아직 설정되지 않았어요.");

  const { data: past } = await db.from("mistake_notes").select("wrong,better").eq("author", me.email).limit(50);
  let out: { answer: string; mistakes: Mistake[] };
  try {
    out = await askGemini(key, t, past || []);
  } catch (e) {
    return await fail(db, f, me, String((e as Error).message || e).slice(0, 300));
  }

  await db.from("feedback_requests").update({ answer: out.answer, answered_at: new Date().toISOString(), by: "gemini", error: "" }).eq("id", f.id);
  await saveMistakes(db, me.email, t.lang, out.mistakes || []);

  const url = "/" + (f.target_type === "drill" ? "drills" : "sessions") + "?fb=" + f.id;
  await pushTo(db, "fb", [me.email], { title: "피드백이 도착했어요", body: short(t.source), url, tag: "fb-" + f.id });
  await pushAdmins(db, "admin-fb", me.email, { title: me.display_name + " 님이 피드백을 요청했어요", body: "자동 답변을 달았어요. " + short(t.source), url: "/", tag: "q-" + f.id });
  return { status: "answered" };
}

async function fail(db: SupabaseClient, f: any, me: Member, msg: string) {
  const tries = (f.tries || 0) + 1;
  await db.from("feedback_requests").update({ error: msg, tries }).eq("id", f.id);
  // 자동 재시도(10분마다)가 남아 있으면 조용히 기다리고, 마지막까지 실패했을 때만 희주에게 알린다
  if (tries >= MAX_TRIES)
    await pushAdmins(db, "admin-fb", "", { title: "자동 피드백 실패", body: me.display_name + " 님 요청: " + msg.slice(0, 80) + " · 정밀 검토 루틴이 대신 답해요. 급하면 '피드백 확인해줘'.", url: "/", tag: "fail-" + f.id });
  return { status: "pending", error: msg, tries };
}

// pg_cron이 10분마다 부른다: 실패한 요청을 요청한 사람 이름으로 다시 시도
async function feedbackRetry(db: SupabaseClient, id: string) {
  const { data: f } = await db.from("feedback_requests").select("id,author,answered_at,claude_answered_at,tries").eq("id", id).maybeSingle();
  if (!f || f.answered_at || f.claude_answered_at || (f.tries || 0) >= MAX_TRIES) return { status: "skip" };
  const { data: me } = await db.from("members").select("email,display_name,is_admin").eq("email", f.author).maybeSingle();
  if (!me) return { status: "skip" };
  return await feedback(db, me as Member, id);
}

type Target = { kind: string; dir: string; lang: "en" | "ko"; context: string; source: string; mine: string; model: any };
async function loadTarget(db: SupabaseClient, type: string, id: string, email: string): Promise<Target | null> {
  if (type === "drill") {
    const [{ data: d }, { data: a }, { data: m }] = await Promise.all([
      db.from("drills").select("*").eq("id", id).maybeSingle(),
      db.from("drill_answers").select("body").eq("drill_id", id).eq("author", email).maybeSingle(),
      db.from("drill_models").select("*").eq("drill_id", id).maybeSingle(),
    ]);
    if (!d) return null;
    const dir = d.dir || "KR→EN";
    return { kind: "번역 연습", dir, lang: dir === "EN→KR" ? "ko" : "en", context: d.context || "", source: d.source || d.ko || "", mine: a?.body || "", model: m };
  }
  const [{ data: s }, { data: v }, { data: m }] = await Promise.all([
    db.from("sessions").select("*").eq("id", id).maybeSingle(),
    db.from("session_versions").select("body").eq("session_id", id).eq("author", email).maybeSingle(),
    db.from("session_models").select("*").eq("session_id", id).maybeSingle(),
  ]);
  if (!s) return null;
  return { kind: "교차번역", dir: s.dir, lang: String(s.dir).startsWith("KR") ? "en" : "ko", context: s.title || "", source: s.source || "", mine: v?.body || "", model: m };
}

const SYSTEM = `너는 통번역사와 카피라이터 두 사람의 한영·영한 번역 공부를 돕는 코치야.
학습자의 번역을 원문, 추천 번역과 비교해서 한국어 해요체로 피드백을 써.
규칙:
- answer: 8줄 이내. 1) 잘한 점 한 줄 2) 틀리거나 어색한 곳을 "내가 쓴 표현 → 더 나은 표현"과 이유로 3) 필요하면 더 나은 전체 번역 한 줄.
- 추천 번역만 정답이 아니야. 추천과 달라도 뜻과 격(말투)이 맞으면 맞다고 분명히 말해.
- 원문 일부를 빠뜨렸으면 짚어 줘.
- 격(구어/문어/광고 카피/기사체)이 맞는지 봐 줘.
- mistakes: 다음에도 또 할 만한 표현 실수만 0~3개. wrong 은 학습자가 실제로 쓴 표현 그대로, better 는 고친 표현, why 는 한 문장.
  학습자의 예전 실수 목록에 같은 실수가 있으면 wrong 을 그 목록의 문자열과 똑같이 써.
- 마크다운 기호(#, *, **)는 쓰지 마.`;

async function askGemini(key: string, t: Target, past: { wrong: string; better: string }[]) {
  const model = t.model
    ? `추천 번역: ${t.model.best}\n다르게 말하면: ${(t.model.alternatives || []).join(" / ")}\n포인트: ${(t.model.notes || []).map((n: any) => n.phrase + " - " + n.why).join(" | ")}`
    : "추천 번역: (없음)";
  const prompt = `[${t.kind} · ${t.dir === "EN→KR" ? "영어→한국어" : "한국어→영어"}]
상황: ${t.context}
원문: ${t.source}
학습자 번역: ${t.mine}
${model}
학습자의 예전 실수: ${past.length ? past.map((p) => p.wrong + " → " + p.better).join(" | ") : "(없음)"}`;
  const payload = {
    systemInstruction: { parts: [{ text: SYSTEM }] },
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.4,
      responseMimeType: "application/json",
      responseSchema: {
        type: "OBJECT",
        properties: {
          answer: { type: "STRING" },
          mistakes: { type: "ARRAY", items: { type: "OBJECT", properties: { wrong: { type: "STRING" }, better: { type: "STRING" }, why: { type: "STRING" } }, required: ["wrong", "better", "why"] } },
        },
        required: ["answer", "mistakes"],
      },
    },
  };
  const out = await callGemini(key, payload);
  if (!out?.answer) throw new Error("Gemini 응답이 비어 있어요.");
  out.answer = String(out.answer).replace(/\*\*/g, "").trim();
  out.mistakes = Array.isArray(out.mistakes) ? out.mistakes.slice(0, 3) : [];
  return out as { answer: string; mistakes: Mistake[] };
}

// 무료 모델을 차례로 시도해 JSON 응답을 돌려준다(피드백·다시 도전 분석이 같이 쓴다)
async function callGemini(key: string, payload: unknown): Promise<any> {
  let last = "";
  const busy = (st: number) => st === 503 || st === 429 || st === 500;
  for (const m of MODELS) {
    let r: Response | null = null;
    for (let attempt = 0; attempt < 2; attempt++) {
      r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify(payload),
      });
      if (!busy(r.status) || attempt === 1) break;
      await r.body?.cancel();
      await new Promise((ok) => setTimeout(ok, 2000));  // 순간 혼잡은 몇 초면 풀린다
    }
    if (!r) continue;
    if (r.status === 404) { last = `모델 ${m} 없음`; await r.body?.cancel(); continue; }
    if (busy(r.status)) { last = r.status === 429 ? "Gemini 무료 한도를 넘었어요." : `Gemini가 붐벼요(${r.status}).`; await r.body?.cancel(); continue; }
    if (!r.ok) {
      const txt = await r.text();
      throw new Error(`Gemini 오류 ${r.status}: ${txt.slice(0, 150)}`);
    }
    const j = await r.json();
    const text = j?.candidates?.[0]?.content?.parts?.map((p: any) => p.text || "").join("") || "";
    return JSON.parse(text);
  }
  throw new Error((last || "사용할 수 있는 Gemini 모델이 없어요.") + " 10분 뒤 자동으로 다시 시도해요.");
}

// ---------- 다시 도전 분석 ----------
const RETRY_SYSTEM = `너는 통번역 공부 모임의 코치야. 학습자가 같은 문장을 1주일 간격으로 다시 번역했어(앞 번역은 보지 않고).
차수별 번역을 비교해서 한국어 해요체로 분석해 줘. 6줄 이내, 마크다운 기호(#, *, **) 없이.
1) 좋아진 점: 앞 차수보다 나아진 표현을 "1차 표현 → 이번 표현"으로 짚기. 없으면 솔직하게 "거의 그대로예요".
2) 반복된 표현: 차수마다 똑같이 쓴 표현이 있으면 그게 괜찮은 선택인지, 습관(직역·번역투·같은 실수)인지 이유와 함께.
3) 아직 남은 점: 이번 번역에서 고치면 좋을 곳 1~2개.
4) 다음에 써먹을 팁 한 줄.
추천 번역만 정답이 아니야. 뜻과 격(말투)이 맞으면 맞다고 말해.`;

async function retryCompare(db: SupabaseClient, me: Member, id: string) {
  const { data: r } = await db.from("drill_retries").select("*").eq("id", id).eq("author", me.email).maybeSingle();
  if (!r) return { status: "missing" };
  if (r.analyzed_at) return { status: "answered" };
  const t = await loadTarget(db, "drill", r.drill_id, me.email);
  if (!t || !t.mine) return { status: "missing" };
  const { data: prev } = await db.from("drill_retries").select("attempt,body").eq("drill_id", r.drill_id).eq("author", me.email).lt("attempt", r.attempt).order("attempt");
  const tries = [t.mine, ...(prev || []).map((p: any) => p.body), r.body];
  const key = Deno.env.get("GEMINI_API_KEY") || (await secret(db, "gemini_api_key"));
  if (!key) return { status: "pending", error: "Gemini API 키가 아직 설정되지 않았어요." };
  const { data: past } = await db.from("mistake_notes").select("wrong,better").eq("author", me.email).order("count", { ascending: false }).limit(30);
  const prompt = `[번역 연습 · ${t.dir === "EN→KR" ? "영어→한국어" : "한국어→영어"}]
상황: ${t.context}
원문: ${t.source}
${tries.map((b, i) => `${i + 1}차 번역: ${b}`).join("\n")}
추천 번역: ${t.model ? t.model.best : "(없음)"}
학습자의 자주 하는 실수: ${(past || []).length ? (past || []).map((p: any) => p.wrong + " → " + p.better).join(" | ") : "(없음)"}`;
  let out: any;
  try {
    out = await callGemini(key, {
      systemInstruction: { parts: [{ text: RETRY_SYSTEM }] },
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.4, responseMimeType: "application/json",
        responseSchema: { type: "OBJECT", properties: { analysis: { type: "STRING" } }, required: ["analysis"] } },
    });
  } catch (e) {
    return { status: "pending", error: String((e as Error).message || e).slice(0, 200) };
  }
  const analysis = String(out?.analysis || "").replace(/\*\*/g, "").trim();
  if (!analysis) return { status: "pending", error: "Gemini 응답이 비어 있어요." };
  await db.from("drill_retries").update({ analysis, analyzed_at: new Date().toISOString() }).eq("id", r.id);
  return { status: "answered" };
}

// 같은 사람의 같은 실수(대소문자·공백 무시)가 있으면 횟수만 올린다
async function saveMistakes(db: SupabaseClient, email: string, lang: string, list: Mistake[]) {
  if (!list.length) return;
  const { data: have } = await db.from("mistake_notes").select("id,wrong,count").eq("author", email);
  const norm = (s: string) => String(s || "").trim().toLowerCase().replace(/\s+/g, " ");
  const today = new Date().toISOString().slice(0, 10);
  for (const m of list) {
    if (!m.wrong || !m.better) continue;
    const hit = (have || []).find((h) => norm(h.wrong) === norm(m.wrong));
    if (hit) await db.from("mistake_notes").update({ count: hit.count + 1, last_seen: today, better: m.better, why: m.why || "" }).eq("id", hit.id);
    else await db.from("mistake_notes").insert({ author: email, lang, wrong: m.wrong.slice(0, 200), better: m.better.slice(0, 200), why: (m.why || "").slice(0, 300) });
  }
}

// ---------- 건의 ----------
async function requestPosted(db: SupabaseClient, me: Member, id: string) {
  const { data: r } = await db.from("requests").select("title,author").eq("id", id).maybeSingle();
  if (!r || r.author !== me.email) return { ok: false };
  const n = await pushAdmins(db, "admin-req", me.email, { title: "새 건의: " + me.display_name, body: short(r.title), url: "/requests", tag: "req-" + id });
  return { ok: true, sent: n };
}

async function requestDone(db: SupabaseClient, id: string) {
  const { data: r } = await db.from("requests").select("title,author,status,claude_note").eq("id", id).maybeSingle();
  if (!r || r.status !== "done") return { ok: false };
  const n = await pushTo(db, "done", [r.author], { title: "건의가 완료됐어요 ✓", body: short(r.title) + (r.claude_note ? " · " + short(r.claude_note) : ""), url: "/requests?done=" + id, tag: "done-" + id });
  return { ok: true, sent: n };
}

async function contentAdded(db: SupabaseClient, b: any) {
  const n = Number(b.n) || 0;
  if (!n) return { ok: false };
  const drill = b.kind === "drills";
  const parts = drill ? [b.kren ? "한→영 " + b.kren : "", b.enkr ? "영→한 " + b.enkr : ""].filter(Boolean).join(", ") : "";
  const { data } = await db.from("members").select("email");
  const sent = await pushTo(db, "content", (data || []).map((m) => m.email), {
    title: drill ? "새 번역 연습 " + n + "문장이 올라왔어요" : "새 교차번역 원문 " + n + "개가 올라왔어요",
    body: drill ? parts + " · 오늘 1~2문장 풀어 볼까요?" : "모임 전까지 각자 번역을 저장해 주세요.",
    url: drill ? "/drills" : "/sessions",
    tag: "content-" + b.kind,
  });
  return { ok: true, sent };
}

// ---------- Claude 정밀 검토 · 주간 리포트 ----------
async function claudeRequested(db: SupabaseClient, me: Member, id: string) {
  const { data: f } = await db.from("feedback_requests").select("id,author,target_type,target_id,claude_requested_at,claude_answered_at").eq("id", id).maybeSingle();
  if (!f || f.author !== me.email || !f.claude_requested_at || f.claude_answered_at) return { ok: false };
  const t = await loadTarget(db, f.target_type, f.target_id, me.email);
  const n = await pushAdmins(db, "admin-fb", me.email, { title: me.display_name + " 님이 Claude 정밀 검토를 요청했어요", body: (t ? short(t.source) + " · " : "") + "루틴이 곧 처리해요. 급하면 Claude에게 '피드백 확인해줘'.", url: "/", tag: "cr-" + id });
  return { ok: true, sent: n };
}
async function claudeAnswered(db: SupabaseClient, id: string) {
  const { data: f } = await db.from("feedback_requests").select("id,author,target_type,target_id,claude_verdict").eq("id", id).maybeSingle();
  if (!f) return { ok: false };
  const t = await loadTarget(db, f.target_type, f.target_id, f.author);
  const tag = f.claude_verdict === "fixed" ? " (Gemini 설명을 바로잡았어요)" : f.claude_verdict === "ok" ? " (Gemini 설명도 맞아요 ✓)" : "";
  const url = "/" + (f.target_type === "drill" ? "drills" : "sessions") + "?fb=" + f.id;
  const n = await pushTo(db, "claude", [f.author], { title: "Claude 정밀 검토가 도착했어요" + tag, body: t ? short(t.source) : "", url, tag: "ca-" + id });
  return { ok: true, sent: n };
}
async function reportAdded(db: SupabaseClient, id: string) {
  const { data: r } = await db.from("weekly_reports").select("author,body").eq("id", id).maybeSingle();
  if (!r) return { ok: false };
  const n = await pushTo(db, "report", [r.author], { title: "이번 주 번역 리포트가 도착했어요", body: short(r.body), url: "/drills?report=1", tag: "report-" + id });
  return { ok: true, sent: n };
}

// ---------- 교차번역 저장 → 아직 안 한 사람에게 ----------
async function sessionSaved(db: SupabaseClient, sessionId: string, author: string) {
  const { data: s } = await db.from("sessions").select("id,no,title").eq("id", sessionId).maybeSingle();
  if (!s) return { ok: false };
  const { data: round } = await db.from("sessions").select("id").eq("no", s.no);
  const ids = (round || []).map((r) => r.id);
  const { data: vs } = await db.from("session_versions").select("session_id,author,body,updated_at").in("session_id", ids);
  const saved = (vs || []).filter((v) => String(v.body || "").trim());
  // 한 번에 여러 원문을 저장해도 알림은 한 번만: 같은 사람이 같은 회차에 10분 안에 다른 원문을 이미 저장했으면 건너뛴다
  const recent = Date.now() - 10 * 60 * 1000;
  if (saved.some((v) => v.author === author && v.session_id !== sessionId && new Date(v.updated_at).getTime() > recent)) return { ok: true, skipped: "recent" };
  const { data: who } = await db.from("members").select("email,display_name");
  const name = (who || []).find((m) => m.email === author)?.display_name || "상대";
  const done = saved.filter((v) => v.author === author).length;
  // 이 원문에 아직 번역을 저장하지 않은 사람에게만
  const to = (who || []).map((m) => m.email).filter((e) => e !== author && !saved.some((v) => v.author === e && v.session_id === sessionId));
  if (!to.length) return { ok: true, sent: 0 };
  const n = await pushTo(db, "nudge", to, {
    title: name + " 님이 교차번역 " + s.no + "회차 번역을 저장했어요",
    body: "원문 " + done + "/" + ids.length + "개 저장 · 내 번역도 저장하면 서로 비교할 수 있어요. (" + short(s.title) + ")",
    url: "/sessions?sess=" + s.id,
    tag: "nudge-" + s.no,
  });
  return { ok: true, sent: n };
}

// ---------- 코멘트 답장 ----------
const PATH: Record<string, string> = { term: "/terms", session: "/sessions", tagline: "/taglines", daily: "/", drill: "/drills", request: "/requests" };
async function commentReply(db: SupabaseClient, me: Member, id: string) {
  const { data: c } = await db.from("comments").select("id,author,body,parent_id,target_type").eq("id", id).maybeSingle();
  if (!c || c.author !== me.email || !c.parent_id) return { ok: false };
  const { data: p } = await db.from("comments").select("author").eq("id", c.parent_id).maybeSingle();
  // 원래 코멘트 쓴 사람 + 같은 스레드에 답장한 사람(나 제외)
  const { data: rs } = await db.from("comments").select("author").eq("parent_id", c.parent_id);
  const to = [...new Set([p?.author, ...(rs || []).map((x) => x.author)].filter((e) => e && e !== me.email))] as string[];
  if (!to.length) return { ok: true, sent: 0 };
  const n = await pushTo(db, "reply", to, { title: me.display_name + " 님이 답장했어요", body: short(c.body), url: PATH[c.target_type] || "/", tag: "reply-" + c.parent_id });
  return { ok: true, sent: n };
}

// ---------- 웹 푸시 ----------
let vapidReady = false;
async function initVapid(db: SupabaseClient) {
  if (vapidReady) return true;
  const [pub, priv] = await Promise.all([secret(db, "vapid_public_key"), secret(db, "vapid_private_key")]);
  if (!pub || !priv) return false;
  webpush.setVapidDetails(SITE, pub, priv);
  vapidReady = true;
  return true;
}
async function pushAdmins(db: SupabaseClient, kind: string, except: string, msg: Record<string, string>) {
  const { data } = await db.from("members").select("email").eq("is_admin", true);
  const to = (data || []).map((m) => m.email).filter((e) => e !== except);
  return to.length ? await pushTo(db, kind, to, msg) : 0;
}
// kind: 알림 종류. 그 종류를 끈 사람(notify_prefs.off)은 뺀다. ""이면 설정과 상관없이 보낸다(테스트 알림).
async function pushTo(db: SupabaseClient, kind: string, emails: string[], msg: Record<string, string>, onlyEndpoint?: string) {
  if (kind && emails.length) {
    const { data: off } = await db.from("notify_prefs").select("author").in("author", emails).contains("off", [kind]);
    const muted = new Set((off || []).map((p) => p.author));
    emails = emails.filter((e) => !muted.has(e));
  }
  if (!emails.length || !(await initVapid(db))) return 0;
  let q = db.from("push_subscriptions").select("*").in("author", emails);
  if (onlyEndpoint) q = q.eq("endpoint", onlyEndpoint);
  const { data: subs } = await q;
  let sent = 0;
  for (const s of subs || []) {
    try {
      await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify(msg), { TTL: 60 * 60 * 24 });
      sent++;
    } catch (e) {
      const code = (e as any)?.statusCode;
      if (code === 404 || code === 410) await db.from("push_subscriptions").delete().eq("endpoint", s.endpoint); // 만료된 구독 정리
    }
  }
  return sent;
}
const short = (s: string) => { const t = String(s || "").replace(/\s+/g, " ").trim(); return t.length > 60 ? t.slice(0, 58) + "…" : t; };
