// assist: 피드백 자동 답변(Gemini 무료 API) + 웹 푸시 알림.
// 앱(docs/index.html)이 로그인한 사용자 토큰으로 부른다. 멤버만 쓸 수 있다.
//   { action: "feedback", id }        → 내 피드백 요청에 Gemini가 설명을 달고, 오답 노트를 갱신하고, 푸시를 보낸다
//   { action: "request-posted", id }  → 새 건의가 올라왔다고 관리자(희주)에게 푸시
//   { action: "test-push" }           → 내 기기로 테스트 푸시
//   { action: "comment-reply", id }   → 내 답장을 원래 코멘트 쓴 사람에게 푸시
// DB 트리거(pg_net)가 x-hook-secret 헤더로 부른다:
//   { action: "request-done", id }    → 건의가 완료되면 올린 사람에게 푸시
// 인증: 사용자 호출은 함수 안에서 토큰을 확인한다(getUser + members). 트리거 호출은 JWT가 없어서
//       배포할 때 verify_jwt=false 로 두고, hook_secret 으로 확인한다.
// 비밀값: GEMINI_API_KEY 는 Edge Function 시크릿(없으면 private.app_secrets 의 gemini_api_key),
//         VAPID 키는 private.app_secrets 에서 읽는다. 요금: Google 프로젝트에 결제를 연결하지 않으면 무료 한도를 넘어도 과금되지 않고 429 로 실패한다.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SITE = "https://root-register.vercel.app";
// 무료 티어 모델 이름이 바뀔 수 있어서 차례로 시도한다(404면 다음 후보). GEMINI_MODEL 시크릿이 있으면 그것부터.
const MODELS = [Deno.env.get("GEMINI_MODEL"), "gemini-3-flash", "gemini-3-flash-preview", "gemini-2.5-flash"].filter(Boolean) as string[];

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
    if (body.action === "test-push") {
      const n = await pushTo(db, [email], { title: "알림이 켜졌어요", body: "피드백 답변과 새 소식을 이 기기로 알려 드릴게요.", url: "/" });
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
  await pushTo(db, [me.email], { title: "피드백이 도착했어요", body: short(t.source), url, tag: "fb-" + f.id });
  await pushAdmins(db, me.email, { title: me.display_name + " 님이 피드백을 요청했어요", body: "자동 답변을 달았어요. " + short(t.source), url: "/", tag: "q-" + f.id });
  return { status: "answered" };
}

async function fail(db: SupabaseClient, f: any, me: Member, msg: string) {
  await db.from("feedback_requests").update({ error: msg, tries: (f.tries || 0) + 1 }).eq("id", f.id);
  // 자동 답변이 안 되면 희주가 Claude에게 "피드백 확인해줘"로 처리할 수 있게 알린다
  await pushAdmins(db, "", { title: "자동 피드백 실패", body: me.display_name + " 님 요청: " + msg.slice(0, 80) + " · Claude에게 '피드백 확인해줘'라고 해 주세요.", url: "/", tag: "fail-" + f.id });
  return { status: "pending", error: msg };
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
  let last = "";
  for (const m of MODELS) {
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify(payload),
    });
    if (r.status === 404) { last = `모델 ${m} 없음`; continue; }
    if (!r.ok) {
      const txt = await r.text();
      throw new Error(r.status === 429 ? "Gemini 무료 한도를 넘었어요. 잠시 뒤 다시 시도해 주세요." : `Gemini 오류 ${r.status}: ${txt.slice(0, 150)}`);
    }
    const j = await r.json();
    const text = j?.candidates?.[0]?.content?.parts?.map((p: any) => p.text || "").join("") || "";
    const out = JSON.parse(text);
    if (!out?.answer) throw new Error("Gemini 응답이 비어 있어요.");
    out.answer = String(out.answer).replace(/\*\*/g, "").trim();
    out.mistakes = Array.isArray(out.mistakes) ? out.mistakes.slice(0, 3) : [];
    return out as { answer: string; mistakes: Mistake[] };
  }
  throw new Error(last || "사용할 수 있는 Gemini 모델이 없어요.");
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
  const n = await pushAdmins(db, me.email, { title: "새 건의: " + me.display_name, body: short(r.title), url: "/requests", tag: "req-" + id });
  return { ok: true, sent: n };
}

async function requestDone(db: SupabaseClient, id: string) {
  const { data: r } = await db.from("requests").select("title,author,status,claude_note").eq("id", id).maybeSingle();
  if (!r || r.status !== "done") return { ok: false };
  const n = await pushTo(db, [r.author], { title: "건의가 완료됐어요 ✓", body: short(r.title) + (r.claude_note ? " · " + short(r.claude_note) : ""), url: "/requests?done=" + id, tag: "done-" + id });
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
  const n = await pushTo(db, to, { title: me.display_name + " 님이 답장했어요", body: short(c.body), url: PATH[c.target_type] || "/", tag: "reply-" + c.parent_id });
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
async function pushAdmins(db: SupabaseClient, except: string, msg: Record<string, string>) {
  const { data } = await db.from("members").select("email").eq("is_admin", true);
  const to = (data || []).map((m) => m.email).filter((e) => e !== except);
  return to.length ? await pushTo(db, to, msg) : 0;
}
async function pushTo(db: SupabaseClient, emails: string[], msg: Record<string, string>) {
  if (!(await initVapid(db))) return 0;
  const { data: subs } = await db.from("push_subscriptions").select("*").in("author", emails);
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
