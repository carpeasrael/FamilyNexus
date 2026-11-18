#!/usr/bin/env node
/*
 * OQ-Selbsttest des Quality-Gates v2 (Funktionsprüfung der Schutz- und Ablaufmechanismen).
 * Läuft in einem temporären Git-Repository – das Projekt wird nicht verändert.
 * Aufruf (im Projekt-Root):  node .quality/oq/oq-selftest.mjs [--keep]
 * Exit-Code 0 nur, wenn alle Testfälle bestanden sind. Die Ausgabe ist das OQ-Protokoll.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const SRC = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const T = fs.mkdtempSync(path.join(os.tmpdir(), 'qg-oq-'));
const X = fs.mkdtempSync(path.join(os.tmpdir(), 'qg-oq-tr-'));
const QG = path.join(T, '.quality', 'bin', 'qg.mjs');
const results = [];
const sh = (cmd, args, o = {}) => spawnSync(cmd, args, { cwd: T, encoding: 'utf8', env: { ...process.env, CLAUDE_PROJECT_DIR: T, QG_ADMIN: '', ...o.env }, input: o.input });
const qg = (...a) => sh('node', [QG, ...a]);
const hook = (name, payload) => sh('node', [QG, 'hook', name], { input: JSON.stringify(payload) });
const pre = (agent, tool, input) => hook('pre-tool', { agent_type: agent, tool_name: tool, tool_input: input });
const tc = (id, title, cond, detail = '') => results.push({ id, title, pass: !!cond, detail });
const w = (p, c) => { fs.mkdirSync(path.dirname(path.join(T, p)), { recursive: true }); fs.writeFileSync(path.join(T, p), c); };
const O = 'qg-orchestrator';

// ---------- Aufbau
for (const d of ['.quality', '.claude', '.githooks']) fs.cpSync(path.join(SRC, d), path.join(T, d), { recursive: true, filter: (p) => !p.includes(`${path.sep}state`) && !p.includes(`${path.sep}runs${path.sep}`) });
const cfgP = path.join(T, '.quality', 'config.json');
const cfg = JSON.parse(fs.readFileSync(cfgP, 'utf8'));
cfg.designChecks = [{ id: 'tests-red', cmd: 'node --test', expect: 'fail', required: true }, { id: 'traceability', builtin: 'traceability', required: true }];
cfg.checks = [{ id: 'test', cmd: 'node --test', required: true }, { id: 'traceability', builtin: 'traceability', required: true }];
// Projektspezifische Anpassungen dürfen den Selbsttest nicht verfälschen: Testpfade und Governance-Dateien des Testszenarios sicherstellen
cfg.testGlobs = [...new Set([...cfg.testGlobs, 'tests/**', '**/*.test.mjs'])];
cfg.governanceGlobs = [...new Set([...cfg.governanceGlobs, 'package.json'])];
cfg.protectedGlobs = [...new Set([...cfg.protectedGlobs, '.idea/**', '.claude/**', '.quality/**'])];
fs.writeFileSync(cfgP, JSON.stringify(cfg, null, 2));
w('.gitignore', '.quality/state/\nnode_modules/\n');
sh('git', ['init', '-q', '-b', 'main']); sh('git', ['config', 'user.email', 'oq@example.invalid']); sh('git', ['config', 'user.name', 'OQ']); sh('git', ['config', 'core.hooksPath', '.githooks']);
w('src/base.mjs', 'export const base = 1;\n'); sh('git', ['add', '-A']); sh('git', ['commit', '-q', '--no-verify', '-m', 'chore: baseline']);

// simulierte Transcripts je Modell (außerhalb des Repos)
const TR = {};
for (const m of ['claude-sonnet-5-5', 'claude-opus-5-5', 'claude-haiku-5-5']) { TR[m] = path.join(X, `${m}.jsonl`); fs.writeFileSync(TR[m], JSON.stringify({ type: 'assistant', message: { model: `${m}-20261101` } }) + '\n'); }
const lvModel = (lv) => cfg.levels.find((l) => l.id === lv).model;
let aid = 0;
function runAgent(agent, msg, transcript, prompt = 'prüfe') {
  const id = `ag-${++aid}`; const s = pre(O, 'Agent', { subagent_type: agent, prompt });
  if (s.status !== 0) return { spawn: s, stop: null };
  hook('subagent-start', { agent_type: agent, agent_id: id });
  return { spawn: s, stop: hook('subagent-stop', { agent_type: agent, agent_id: id, last_assistant_message: msg, agent_transcript_path: transcript, stop_hook_active: false }) };
}
const V = (extra = {}) => `Begründung.\n<<<QG-VERDICT\n${JSON.stringify({ result: 'PASS', summary: 'ok', findings: [], evidence: ['geprüft'], ...extra })}\nQG-VERDICT>>>`;
const FAIL1 = V({ result: 'FAIL', findings: [{ id: 'F-1', severity: 'MAJOR', rule: 'STD-SEC-01', title: 'Validierung fehlt' }] });
const ACC = V({ ac_results: [{ ac: 'AC-001', status: 'PASS', evidence: 'AC-001 Test grün' }] });
function round(phase, lv, override = {}, model = lvModel(lv)) {
  let spawnOk = true;
  for (const d of cfg.phases[phase].domains) for (const s of cfg.phases[phase].slots) {
    const msg = override[`${d}-${s}`] ?? (d === 'acceptance' ? ACC : V());
    const r = runAgent(`qg-rev-${d}-${s}-${lv}`, msg, override.transcript?.[`${d}-${s}`] || TR[model]);
    if (r.spawn.status !== 0) spawnOk = false;
  }
  return spawnOk;
}
const run = () => JSON.parse(fs.readFileSync(path.join(T, '.quality/runs', JSON.parse(fs.readFileSync(path.join(T, '.quality/state/current.json'))).runId, 'run.json')));
let designRev = 0;
const touchDesign = () => fs.appendFileSync(path.join(T, `.quality/runs/${run().id}/design.md`), `\nÜberarbeitung ${++designRev}\n`);

// ---------- P0/P1 Komplexität mit Gegenprüfung
let r = qg('init', '--title', 'OQ Testauftrag'); tc('OQ-01', 'Run anlegen', r.status === 0, r.stderr);
const RID = run().id;
r = pre(O, 'Agent', { subagent_type: 'qg-req-low', prompt: 'x' }); tc('OQ-02', 'Agentenstart vor Komplexitätsbewertung blockiert', r.status === 2, r.stderr);
r = qg('tier', 'set', 'low', '--reason', 'klein'); tc('OQ-03', 'tier set ohne unabhängige Gegenprüfung verweigert', r.status !== 0, r.stderr);
let a = runAgent('qg-tiercheck', '<<<QG-TIER\n{"tier":"medium","reasons":["mehrere Module"]}\nQG-TIER>>>', TR['claude-opus-5-5']);
tc('OQ-04', 'Gegenprüfung Komplexität (qg-tiercheck) läuft und wird erfasst', a.spawn.status === 0 && run().tierCheck?.tier === 'medium', a.spawn.stderr);
r = pre(O, 'Agent', { subagent_type: 'qg-tiercheck', prompt: 'x' }); tc('OQ-05', 'Wiederholte Komplexitäts-Gegenprüfung blockiert', r.status === 2, r.stderr);
r = qg('tier', 'set', 'low', '--reason', 'klein'); tc('OQ-06', 'Stufe unter Gegenprüfung (medium) verweigert – höhere Bewertung gilt', r.status !== 0, r.stderr);
r = qg('tier', 'set', 'medium', '--reason', 'Rubrik medium'); tc('OQ-07', 'Komplexität medium → Sonnet 5.5 · extra high', r.status === 0 && run().level === 'medium' && /extra high/.test(r.stdout), r.stdout + r.stderr);

// Start-Guards
r = pre(O, 'Agent', { subagent_type: 'qg-req-medium', prompt: 'x', model: 'opus' }); tc('OQ-08', 'Modell-Override blockiert', r.status === 2, r.stderr);
r = pre(O, 'Agent', { subagent_type: 'qg-req-medium', prompt: 'x', effort: 'max' }); tc('OQ-09', 'Effort-Override blockiert', r.status === 2, r.stderr);
r = pre(O, 'Agent', { subagent_type: 'qg-req-low', prompt: 'x' }); tc('OQ-10', 'Falsche Stufe blockiert', r.status === 2, r.stderr);
r = pre(undefined, 'Agent', { subagent_type: 'qg-req-medium', prompt: 'x' }); tc('OQ-11', 'Mensch-Sitzung startet keine qg-Agenten', r.status === 2, r.stderr);
r = pre(O, 'Agent', { subagent_type: 'general-purpose', prompt: 'x' }); tc('OQ-12', 'Orchestrator startet keine fremden Agenten', r.status === 2, r.stderr);
r = pre('qg-impl-medium', 'Agent', { subagent_type: 'qg-req-medium', prompt: 'x' }); tc('OQ-13', 'Unteragenten starten keine Agenten', r.status === 2, r.stderr);

// ---------- P2 Anforderungen + Gegenprüfung
r = pre(O, 'Agent', { subagent_type: 'qg-req-medium', prompt: 'x' }); tc('OQ-14', 'Anforderungs-Agent startbar', r.status === 0, r.stderr);
const REQ = `.quality/runs/${RID}/requirements.md`;
r = pre('qg-req-medium', 'Write', { file_path: path.join(T, 'src/x.mjs') }); tc('OQ-15', 'Anforderungs-Agent schreibt keinen Code', r.status === 2, r.stderr);
r = pre('qg-req-medium', 'Write', { file_path: path.join(T, REQ) }); tc('OQ-16', 'Anforderungs-Agent schreibt requirements.md', r.status === 0, r.stderr);
w(REQ, '# Anforderung\n## Abnahmekriterien\n- **AC-001** – add addiert\n## Offene Fragen\n- **Q-01** Ganzzahlen? — Vorschlag: ja\n');
r = qg('req', 'lock', '--approved-by', 'OQ'); tc('OQ-17', 'Freigabe ohne Gegenprüfung der Anforderungen verweigert', r.status !== 0 && /Gegenprüfung/.test(r.stderr), r.stderr);
a = runAgent('qg-reqcheck-medium', V(), TR['claude-sonnet-5-5']); tc('OQ-18', 'Gegenprüfer Anforderungen (qg-reqcheck) läuft', a.spawn.status === 0, a.spawn.stderr);
r = pre(O, 'Agent', { subagent_type: 'qg-reqcheck-medium', prompt: 'x' }); tc('OQ-19', 'Gleicher Anforderungsstand nicht erneut prüfbar', r.status === 2, r.stderr);
qg('gate'); r = qg('req', 'lock', '--approved-by', 'OQ'); tc('OQ-20', 'Freigabe mit offener Frage verweigert', r.status !== 0 && /Offene Fragen/.test(r.stderr), r.stderr);
w(REQ, '# Anforderung\n## Abnahmekriterien\n- **AC-001** – add addiert zwei Zahlen\n## Offene Fragen\n- **Q-01** Ganzzahlen? — beantwortet: ja\n');
r = qg('req', 'lock', '--approved-by', 'OQ'); tc('OQ-21', 'Geänderte Anforderung braucht neue Gegenprüfung', r.status !== 0, r.stderr);
runAgent('qg-reqcheck-medium', V(), TR['claude-sonnet-5-5']); r = qg('gate');
r = qg('req', 'lock', '--approved-by', 'OQ'); tc('OQ-22', 'Anforderungs-Gate bestanden → Freigabe durch Mensch → Phase design', r.status === 0 && run().phase === 'design', r.stdout + r.stderr);
r = pre('qg-req-medium', 'Edit', { file_path: path.join(T, REQ) }); tc('OQ-23', 'Anforderungen nach Freigabe gesperrt', r.status === 2, r.stderr);

// ---------- P3 Entwurf + Tests vor dem Code
r = pre(O, 'Agent', { subagent_type: 'qg-impl-medium', prompt: 'x' }); tc('OQ-24', 'Implementierung vor Freigabe zur Implementierung blockiert', r.status === 2, r.stderr);
const DES = `.quality/runs/${RID}/design.md`;
r = pre('qg-design-medium', 'Write', { file_path: path.join(T, DES) }); tc('OQ-25', 'Entwurfs-Agent schreibt design.md', r.status === 0, r.stderr);
r = pre('qg-design-medium', 'Write', { file_path: path.join(T, 'src/add.mjs') }); tc('OQ-26', 'Entwurfs-Agent schreibt keinen Code', r.status === 2, r.stderr);
r = pre('qg-test-medium', 'Write', { file_path: path.join(T, 'src/add.mjs') }); tc('OQ-27', 'Test-Agent schreibt keinen Produktionscode', r.status === 2, r.stderr);
r = pre('qg-test-medium', 'Write', { file_path: path.join(T, 'tests/add.test.mjs') }); tc('OQ-28', 'Test-Agent schreibt Tests', r.status === 0, r.stderr);
w(DES, '# Lösungsentwurf\n## Abbildung AC → Umsetzung\n| AC-001 | add() | Unit |\n');
w('tests/add.test.mjs', "import test from 'node:test';\nimport assert from 'node:assert';\nimport { add } from '../src/add.mjs';\ntest('AC-001: add addiert zwei Zahlen', () => assert.strictEqual(add(2, 3), 5));\n");
w('src/add.mjs', 'export const add = (a, b) => a + b;\n');
r = qg('stage'); tc('OQ-29', 'Vor Freigabe nur Tests erlaubt (Code im Stand abgelehnt)', r.status !== 0 && /nur Tests/.test(r.stderr), r.stderr);
fs.rmSync(path.join(T, 'src/add.mjs')); sh('git', ['rm', '-q', '--cached', 'src/add.mjs']);
r = qg('stage'); r = qg('checks'); tc('OQ-30', 'Design-Checks: Tests nachweislich rot + Rückverfolgbarkeit', r.status === 0 && /tests-red/.test(r.stdout), r.stdout + r.stderr);

// ---------- P4 Design-Gate mit Iterationen und Eskalation
let spawnAll = true;
for (let i = 1; i <= 5; i++) { if (i > 1) touchDesign(); spawnAll = round('design', 'medium', { 'security-b': FAIL1 }) && spawnAll; qg('gate'); if (i === 4) { r = qg('escalate', '--reason', 'zu früh'); tc('OQ-31', 'Hochsetzung vor 5 Iterationen verweigert', r.status !== 0, r.stderr); } }
tc('OQ-32', 'Design-Gate: 8 Gegenprüfer je Runde (4 Domänen × A/B) startbar', spawnAll);
tc('OQ-33', '5 Iterationen ohne einheitliches Ergebnis gezählt', run().iterations.design.filter((i) => i.result === 'FAIL').length === 5);
r = qg('escalate', '--reason', 'Uneinigkeit Sicherheit'); tc('OQ-34', 'Nach 5 Iterationen: Hochsetzung medium → high (Opus 5.5 · high)', r.status === 0 && run().level === 'high', r.stdout + r.stderr);
r = qg('escalate', '--reason', 'nochmal'); tc('OQ-35', 'Zweite Hochsetzung im selben Fenster verweigert', r.status !== 0, r.stderr);
r = pre(O, 'Agent', { subagent_type: 'qg-rev-security-a-medium', prompt: 'x' }); tc('OQ-36', 'Agenten der alten Stufe nach Hochsetzung blockiert', r.status === 2, r.stderr);
for (let i = 6; i <= 8; i++) { touchDesign(); round('design', 'high', { 'security-b': FAIL1 }); qg('gate'); }
r = pre(O, 'Agent', { subagent_type: 'qg-rev-standards-a-high', prompt: 'x' }); touchDesign();
r = pre(O, 'Agent', { subagent_type: 'qg-rev-standards-a-high', prompt: 'x' });
tc('OQ-37', 'Nach 8 Iterationen: weitere Prüfrunde ohne Pflicht-Hochsetzung blockiert', r.status === 2 && /Pflicht/.test(r.stderr), r.stderr);
r = qg('escalate', '--reason', 'Pflicht nach 8'); tc('OQ-38', 'Pflicht-Hochsetzung high → highx (Opus 5.5 · extra high)', r.status === 0 && run().level === 'highx', r.stdout + r.stderr);
// Iteration 9: nur ein Arbiter widerspricht dem Befund → keine Freigabe
round('design', 'highx', { 'security-b': FAIL1 }); qg('gate');
const ruling = (d) => `<<<QG-RULING\n${JSON.stringify({ items: [{ domain: 'security', slot: 'b', finding: 'F-1', decision: d, reason: 'Die Validierung ist im Entwurf in Abschnitt Datenfluss vorgesehen. Der Befund trifft daher nicht zu.' }] })}\nQG-RULING>>>`;
r = pre(O, 'Agent', { subagent_type: 'qg-arb-a-high', prompt: 'DISPUTE: security-b' }); tc('OQ-39', 'Arbiter nur auf aktueller Stufe (≥ high)', r.status === 2, r.stderr);
runAgent('qg-arb-a-highx', ruling('FALSE_POSITIVE'), TR['claude-opus-5-5'], 'DISPUTE: security-b F-1');
runAgent('qg-arb-b-highx', ruling('CONFIRMED'), TR['claude-opus-5-5'], 'DISPUTE: security-b F-1');
r = qg('gate'); tc('OQ-40', 'Ein Schiedsspruch allein genügt nicht (A ≠ B) → keine Freigabe', r.status === 1, r.stdout);
r = pre(O, 'Agent', { subagent_type: 'qg-arb-b-highx', prompt: 'DISPUTE: security-b F-1' }); tc('OQ-41', 'Wiederholter Schiedsspruch zum selben Stand blockiert', r.status === 2, r.stderr);
// Iteration 10: beide Arbiter widerlegen → Freigabe zur Implementierung
touchDesign(); round('design', 'highx', { 'security-b': FAIL1 }); qg('gate');
runAgent('qg-arb-a-highx', ruling('FALSE_POSITIVE'), TR['claude-opus-5-5'], 'DISPUTE: security-b F-1');
runAgent('qg-arb-b-highx', ruling('FALSE_POSITIVE'), TR['claude-opus-5-5'], 'DISPUTE: security-b F-1');
r = qg('gate'); tc('OQ-42', 'Design-Gate bestanden (A+B-Schiedsspruch) → Freigabe zur Implementierung', r.status === 0 && run().phase === 'impl' && /Freigabe zur Implementierung erteilt/.test(r.stdout), r.stdout + r.stderr);
r = pre('qg-test-highx', 'Write', { file_path: path.join(T, 'tests/add.test.mjs') }); tc('OQ-43', 'Tests nach Freigabe eingefroren', r.status === 2, r.stderr);
r = pre('qg-design-highx', 'Write', { file_path: path.join(T, DES) }); tc('OQ-44', 'Entwurf nach Freigabe eingefroren', r.status === 2, r.stderr);

// ---------- P5–P7 Implementierung und Code-Gate
r = pre(O, 'Agent', { subagent_type: 'qg-impl-highx', prompt: 'x' }); tc('OQ-45', 'Implementierer nach Freigabe startbar (Stufe bleibt highx)', r.status === 0, r.stderr);
r = pre('qg-impl-highx', 'Write', { file_path: path.join(T, 'tests/add.test.mjs') }); tc('OQ-46', 'Implementierer ändert keine Tests', r.status === 2, r.stderr);
r = pre('qg-impl-highx', 'Edit', { file_path: path.join(T, 'package.json') }); tc('OQ-47', 'Implementierer ändert keine Governance-Dateien', r.status === 2, r.stderr);
r = pre('qg-impl-highx', 'Write', { file_path: path.join(T, '.idea/workspace.xml') }); tc('OQ-48', 'IDE-Konfiguration (.idea) geschützt', r.status === 2, r.stderr);
w('src/add.mjs', '/** Addiert a und b. */\nexport const add = (a, b) => a + b;\n');
r = qg('stage'); r = qg('checks'); tc('OQ-49', 'Code-Checks grün', r.status === 0 && run().phase === 'code', r.stdout + r.stderr);
round('code', 'highx', { transcript: { 'performance-a': TR['claude-haiku-5-5'] } });
r = qg('gate'); tc('OQ-50', 'Falsches Modell (Transcript-Nachweis) → Gate scheitert, zählt nicht als Iteration', r.status === 1 && /falsches Modell/.test(r.stdout) && run().iterations.code.length === 0, r.stdout);
w('src/add.mjs', '/** Addiert a und b. */\nexport const add = (a, b) => a + b; // v2\n'); qg('stage'); qg('checks');
r = { ok: round('code', 'highx') }; r = qg('gate'); tc('OQ-51', 'Code-Gate: 10 Gegenprüfer (5 Domänen × A/B) inkl. Abnahme → bestanden', r.status === 0, r.stdout + r.stderr);
// Stopp-Regel per Zustandsinjektion prüfen
const rp = path.join(T, `.quality/runs/${RID}/run.json`); const backup = fs.readFileSync(rp, 'utf8'); const inj = JSON.parse(backup);
inj.iterations.code = Array.from({ length: 11 }, (_, i) => ({ n: i + 1, stand: `x${i}`, level: 'highx', result: 'FAIL' }));
inj.escalations.push({ phase: 'code', atFail: 5, from: 'highx', to: 'highmax' }, { phase: 'code', atFail: 8, from: 'highmax', to: 'highmax' });
fs.writeFileSync(rp, JSON.stringify(inj));
r = pre(O, 'Agent', { subagent_type: 'qg-impl-highx', prompt: 'x' }); tc('OQ-52', 'Nach 11 Iterationen ohne Einigung: Stopp, Entscheidung durch Menschen', r.status === 2 && /Menschen/.test(r.stderr), r.stderr);
fs.writeFileSync(rp, backup);
const origTest = fs.readFileSync(path.join(T, 'tests/add.test.mjs'), 'utf8');
w('tests/add.test.mjs', origTest + '// verändert\n'); qg('stage');
r = qg('gate'); tc('OQ-53', 'Nach Freigabe veränderte Tests lassen Code-Gate scheitern', r.status === 1 && /Tests nach Freigabe/.test(r.stdout), r.stdout);
w('tests/add.test.mjs', origTest); qg('stage');
r = qg('gate'); tc('OQ-54', 'Zurück auf geprüften Stand → Gate wieder bestanden (Hash-Bindung)', r.status === 0, r.stdout + r.stderr);

// Guards (Shell)
r = pre('qg-rev-standards-a-highx', 'Bash', { command: 'git diff --cached' }); tc('OQ-55', 'Prüfer: lesender git-Befehl erlaubt', r.status === 0, r.stderr);
r = pre('qg-rev-standards-a-highx', 'Bash', { command: 'echo x > src/add.mjs' }); tc('OQ-56', 'Prüfer: Schreiben per Shell blockiert', r.status === 2, r.stderr);
r = pre('qg-rev-standards-a-highx', 'Read', { file_path: path.join(T, `.quality/state/${RID}/verdicts/x.json`) }); tc('OQ-57', 'Prüfer: fremde Ergebnisse nicht lesbar (Unabhängigkeit)', r.status === 2, r.stderr);
r = pre('qg-rev-standards-a-highx', 'Read', { file_path: path.join(T, DES) }); tc('OQ-58', 'Prüfer: Entwurf lesbar', r.status === 0, r.stderr);
r = pre('qg-impl-highx', 'Bash', { command: 'git commit -m "x"' }); tc('OQ-59', 'Implementierer committet nicht', r.status === 2, r.stderr);
r = pre(O, 'Bash', { command: 'git add .' }); tc('OQ-60', 'Orchestrator: Staging nur über qg stage', r.status === 2, r.stderr);
r = pre(O, 'Bash', { command: 'git commit --no-verify -m "x"' }); tc('OQ-61', 'Commit mit --no-verify blockiert', r.status === 2, r.stderr);
r = pre(undefined, 'Bash', { command: 'git -c core.hooksPath=/dev/null commit -m x' }); tc('OQ-62', 'Hook-Umgehung per git -c blockiert', r.status === 2, r.stderr);
r = pre('qg-impl-highx', 'Bash', { command: 'curl https://example.org' }); tc('OQ-63', 'Netzwerkwerkzeuge gesperrt', r.status === 2, r.stderr);
r = pre(O, 'Bash', { command: 'node .quality/bin/qg.mjs hook subagent-stop' }); tc('OQ-64', 'Manueller Hook-Aufruf (Fälschung) blockiert', r.status === 2, r.stderr);
r = pre(undefined, 'Bash', { command: 'git commit -m "feat: x"' }); tc('OQ-65', 'Commit vor finalize blockiert', r.status === 2, r.stderr);
r = sh('git', ['commit', '-m', 'feat: add']); tc('OQ-66', 'git pre-commit blockiert auch außerhalb von Claude', r.status !== 0, r.stderr);

// ---------- P8 Abschluss + CI
r = qg('finalize'); tc('OQ-67', 'Finalisieren: Nachweise + Bericht', r.status === 0 && fs.existsSync(path.join(T, `.quality/runs/${RID}/report.md`)), r.stdout + r.stderr);
r = pre(O, 'Bash', { command: 'git commit -m "feat(math): add"' }); tc('OQ-68', 'Commit-Guard lässt freigegebenen Stand zu', r.status === 0, r.stderr);
r = sh('git', ['commit', '-q', '-m', 'feat(math): add']); const msg = sh('git', ['log', '-1', '--format=%B']).stdout;
tc('OQ-69', 'Commit mit Trailern QG-Run/QG-Hash/QG-Level', r.status === 0 && msg.includes(`QG-Run: ${RID}`) && msg.includes('QG-Level: highx'), r.stderr + msg);
tc('OQ-70', 'Run nach Commit geschlossen', !fs.existsSync(path.join(T, '.quality/state/current.json')));
r = qg('verify-commit', 'HEAD'); tc('OQ-71', 'CI verify-commit: alle drei Gates nachgewiesen', r.status === 0, r.stdout + r.stderr);
w('src/add.mjs', 'export const add = (a, b) => a - b;\n'); sh('git', ['add', '-A']); sh('git', ['commit', '-q', '--no-verify', '-m', 'fix: heimlich']);
r = qg('verify-commit', 'HEAD'); tc('OQ-72', 'CI erkennt Commit ohne Nachweis', r.status !== 0, r.stderr);

// ---------- Protokoll
const pass = results.every((x) => x.pass);
console.log(`Quality-Gate v2 OQ-Selbsttest  ${new Date().toISOString()}  Node ${process.versions.node}\nTestverzeichnis: ${T}\n`);
console.log(results.map((x) => `${x.pass ? 'BESTANDEN' : 'FEHLER   '}  ${x.id}  ${x.title}${x.pass ? '' : `\n            ${String(x.detail).trim().split('\n').slice(0, 8).join('\n            ')}`}`).join('\n'));
console.log(`\n${results.filter((x) => x.pass).length}/${results.length} bestanden → ${pass ? 'OQ BESTANDEN' : 'OQ NICHT BESTANDEN'}`);
if (pass && !process.argv.includes('--keep')) { fs.rmSync(T, { recursive: true, force: true }); fs.rmSync(X, { recursive: true, force: true }); }
process.exit(pass ? 0 : 1);
