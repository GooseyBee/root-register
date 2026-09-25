// 용어 하나에 대한 예문 4개(+번역)를 Claude로 만들어 terms.examples 에 저장한다.
// 필요한 secret: ANTHROPIC_API_KEY  (supabase secrets set ANTHROPIC_API_KEY=...)
import Anthropic from "npm:@anthropic-ai/sdk@0.128.0";
import { createClient } from "npm:@supabase/supabase-js@2.117.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

type Example = { s: string; t: string };

const schema = {
  type: "object",
  properties: {
    examples: {
      type: "array",
      items: {
        type: "object",
        properties: { s: { type: "string" }, t: { type: "string" } },
        required: ["s", "t"],
        additionalProperties: false,
      },
    },
  },
  required: ["examples"],
  additionalProperties: false,
};

const anthropic = new Anthropic(); // ANTHROPIC_API_KEY

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // 호출한 사람의 권한으로 DB에 접근한다 (RLS가 멤버 여부를 검사).
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });

  const { term_id, replace } = await req.json().catch(() => ({}));
  if (typeof term_id !== "string") return json({ error: "term_id_required" }, 400);

  const { data: term, error } = await supabase.from("terms").select("*").eq("id", term_id).maybeSingle();
  if (error) return json({ error: "db_error" }, 500);
  if (!term) return json({ error: "not_found" }, 404); // 멤버가 아니어도 여기로 온다

  const existing: Example[] = Array.isArray(term.examples) ? term.examples : [];
  const other = term.lang === "ko" ? "English" : "Korean";
  const prompt = [
    "You write example sentences for two language learners: a Korean-English interpreter who needs precise, register-appropriate wording, and a Korean copywriter learning English.",
    `Term: ${term.word}`,
    `Language of the term: ${term.lang === "ko" ? "Korean" : "English"}`,
    `Meaning: ${term.meaning}`,
    `Counterpart expression: ${term.pair}`,
    `Register: ${term.register}`,
    `Domain: ${term.domain}`,
    replace && existing.length ? `Avoid these existing sentences: ${existing.map((x) => x.s).join(" | ")}` : "",
    "Write 4 natural example sentences in the term's language that use the term (inflected as needed). Vary the contexts (news, business, marketing copy, everyday speech where the register allows) and keep each under 25 words.",
    `For each, give an accurate, natural ${other} translation in "t".`,
  ].filter(Boolean).join("\n");

  let generated: Example[];
  try {
    const response = await anthropic.beta.messages.create({
      model: "claude-opus-5",
      max_tokens: 16000,
      betas: ["server-side-fallback-2026-07-01"],
      // @ts-ignore: "default" 형식은 최신 서버 기능이라 SDK 타입보다 앞설 수 있다
      fallbacks: "default",
      output_config: { effort: "low", format: { type: "json_schema", schema } },
      messages: [{ role: "user", content: prompt }],
    });
    if (response.stop_reason === "refusal") return json({ error: "refused" }, 422);
    const text = response.content.find((b) => b.type === "text");
    if (!text || text.type !== "text") return json({ error: "empty" }, 502);
    generated = (JSON.parse(text.text).examples as Example[])
      .map((x) => ({ s: String(x.s).trim(), t: String(x.t).trim() }))
      .filter((x) => x.s);
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) return json({ error: "rate_limited" }, 429);
    if (e instanceof Anthropic.APIError) return json({ error: "upstream", status: e.status }, 502);
    return json({ error: "bad_output" }, 502);
  }
  if (generated.length < 3) return json({ error: "too_few" }, 502);

  const keep = replace ? [] : existing;
  const merged = keep.concat(generated.filter((g) => !keep.some((k) => k.s === g.s))).slice(0, 5);
  const { error: upErr } = await supabase.from("terms").update({ examples: merged }).eq("id", term_id);
  if (upErr) return json({ error: "db_error" }, 500);
  return json({ examples: merged });
});
