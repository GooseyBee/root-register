// claude.ai artifact DB에서 내보낸 JSON(.export/)을 supabase/seed.sql 로 변환한다.
// 사용법: node scripts/artifact-to-seed.mjs .export > supabase/seed.sql
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const dir = process.argv[2] ?? ".export";
const load = (col) => {
  const p = join(dir, col);
  if (!existsSync(p)) return [];
  return readdirSync(p).filter((f) => f.endsWith(".json")).sort()
    .map((f) => ({ id: f.replace(/\.json$/, ""), ...JSON.parse(readFileSync(join(p, f), "utf8")) }));
};
const q = (v) => (v === null || v === undefined || v === "" ? "null" : "'" + String(v).replace(/'/g, "''") + "'");
const qs = (v) => "'" + String(v ?? "").replace(/'/g, "''") + "'";
const j = (v) => qs(JSON.stringify(v ?? null)) + "::jsonb";
const ts = (ms) => (ms ? `to_timestamp(${ms / 1000})` : "now()");
const exs = (t) => (Array.isArray(t.examples) && t.examples.length ? t.examples : t.example ? [{ s: t.example, t: "" }] : []);

const out = ["-- 생성: scripts/artifact-to-seed.mjs (예시 데이터, added_by = null)", "begin;"];
for (const r of load("roots"))
  out.push(`insert into public.roots (id, en, ko, session, note, added_by, created_at) values (${qs(r.id)}, ${j(r.en)}, ${j(r.ko)}, ${r.session ?? "null"}, ${qs(r.note)}, null, ${ts(r.createdAt)}) on conflict (id) do nothing;`);
for (const t of load("terms"))
  out.push(`insert into public.terms (id, word, pair, meaning, examples, register, domain, root_id, lang, added_by, created_at) values (${qs(t.id)}, ${qs(t.word)}, ${qs(t.pair)}, ${qs(t.meaning)}, ${j(exs(t))}, ${qs(t.register || "문어")}, ${qs(t.domain || "일반")}, ${q(t.rootId)}, ${qs(t.lang)}, null, ${ts(t.createdAt)}) on conflict (id) do nothing;`);
for (const s of load("sessions"))
  out.push(`insert into public.sessions (id, no, date, dir, title, source, final, notes, created_at) values (${qs(s.id)}, ${s.no}, ${q(s.date)}, ${qs(s.dir)}, ${qs(s.title)}, ${qs(s.source)}, ${qs(s.final)}, ${qs(s.notes)}, ${ts(s.createdAt)}) on conflict (id) do nothing;`);
for (const t of load("taglines"))
  out.push(`insert into public.taglines (id, text, brief, added_by, created_at) values (${qs(t.id)}, ${qs(t.text)}, ${qs(t.brief)}, null, ${ts(t.createdAt)}) on conflict (id) do nothing;`);
out.push("commit;");
console.log(out.join("\n"));
