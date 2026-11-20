#!/usr/bin/env node
/*
 * qg.mjs v2 — Quality-Gate-Werkzeug für Claude Code (Multi-Agent, Gegenprüfung, Eskalationsleiter)
 * -----------------------------------------------------------------------------------------------
 * Keine Abhängigkeiten (Node >= 20). Aufgaben:
 *   - Run-Steuerung über Phasen: tier → req → design → impl → code → (finalize)
 *   - Drei deterministische Gates: Anforderungs-Gate, Design-Gate (= Freigabe zur Implementierung), Code-Gate
 *   - Iterationszählung je Phase und Eskalationsleiter (Modell + Effort eine Stufe höher)
 *   - Claude-Code-Hooks (pre-tool, post-tool, subagent-start, subagent-stop, session-start)
 *   - Git-Hooks (pre-commit, commit-msg, post-commit), CI-Nachprüfung (verify-commit)
 *   - Generator der Agentendateien je Ausführungsstufe (gen-agents), Installationsprüfung (doctor)
 * Sicherheitsprinzip: fail-closed für alle qg-Rollen und für Commits. Exit 2 in PreToolUse = blockiert.
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';

// ------------------------------------------------------------------ Basis
const EMPTY_TREE = '4b825dc642cb6eb9a060e54bf8d69288fbee4904';
const BLOCKING = new Set(['BLOCKER', 'MAJOR', 'MINOR']);
const SEVERITIES = new Set(['BLOCKER', 'MAJOR', 'MINOR', 'INFO']);
const HASH_EXCLUDES = [':(exclude).quality/runs', ':(exclude).quality/state'];
const DIFF_BASE_ARGS = ['-c', 'core.quotepath=off', 'diff', '--binary', '--no-color', '--no-ext-diff', '--no-textconv', '--no-renames', '--full-index'];
const ORCH_QG_CMDS = new Set(['init', 'tier', 'req', 'design', 'stage', 'checks', 'gate', 'escalate', 'finalize', 'status', 'metrics', 'abort']);

function findRoot() {
  const r = spawnSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' });
  if (r.status === 0 && r.stdout.trim()) return path.resolve(r.stdout.trim());
  if (process.env.CLAUDE_PROJECT_DIR) return path.resolve(process.env.CLAUDE_PROJECT_DIR);
  return process.cwd();
}
const ROOT = findRoot();
const QDIR = path.join(ROOT, '.quality');
const STATE_DIR = path.join(QDIR, 'state');
const RUNS_DIR = path.join(QDIR, 'runs');
const CFG = JSON.parse(fs.readFileSync(path.join(QDIR, 'config.json'), 'utf8'));
const LEVELS = CFG.levels.map((l) => l.id);
const LV = (id) => LEVELS.indexOf(id);
const LEVEL = (id) => CFG.levels[LV(id)];
const LEVEL_RE = LEVELS.join('|');
const POL = CFG.iterationPolicy;

const now = () => new Date().toISOString();
const sha256 = (buf) => crypto.createHash('sha256').update(buf).digest('hex');
const short = (h) => (h || '').slice(0, 12);
const rel = (p) => path.relative(ROOT, path.resolve(ROOT, p)).split(path.sep).join('/');
function readJSON(p, fb = null) { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return fb; } }
function writeJSON(p, obj) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  const tmp = `${p}.${process.pid}.${Date.now()}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 2) + '\n'); fs.renameSync(tmp, p);
}
function appendLog(p, obj) { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.appendFileSync(p, JSON.stringify({ at: now(), ...obj }) + '\n'); }
function createOnce(p, content) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  try { const fd = fs.openSync(p, 'wx'); fs.writeSync(fd, content); fs.closeSync(fd); return true; }
  catch (e) { if (e.code === 'EEXIST') return false; throw e; }
}
function git(args, { buffer = false, allowFail = false } = {}) {
  const r = spawnSync('git', args, { cwd: ROOT, encoding: buffer ? 'buffer' : 'utf8', maxBuffer: 1024 * 1024 * 1024 });
  if (r.status !== 0 && !allowFail) throw new Error(`git ${args.join(' ')} fehlgeschlagen: ${buffer ? r.stderr.toString() : r.stderr}`);
  return r;
}
const headExists = () => git(['rev-parse', '--verify', '-q', 'HEAD'], { allowFail: true }).status === 0;
const baseRef = () => (headExists() ? 'HEAD' : EMPTY_TREE);

// ------------------------------------------------------------------ Glob
function globToRegex(glob) {
  let re = '';
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === '*') {
      if (glob[i + 1] === '*') { const s = glob[i + 2] === '/'; re += s ? '(?:.*/)?' : '.*'; i += s ? 2 : 1; } else re += '[^/]*';
    } else if (c === '?') re += '[^/]';
    else if (c === '{') { const end = glob.indexOf('}', i); re += `(?:${glob.slice(i + 1, end).split(',').map((s) => s.replace(/[.+^$()|[\]\\]/g, '\\$&')).join('|')})`; i = end; }
    else re += c.replace(/[.+^$()|[\]\\]/g, '\\$&');
  }
  return new RegExp(`^${re}$`);
}
const globCache = new Map();
function matchAny(file, globs = []) {
  const f = file.split(path.sep).join('/');
  return globs.some((g) => { if (!globCache.has(g)) globCache.set(g, globToRegex(g)); return globCache.get(g).test(f); });
}

// ------------------------------------------------------------------ Diff / Hashes
const stagedHash = () => sha256(git([...DIFF_BASE_ARGS, '--cached', baseRef(), '--', '.', ...HASH_EXCLUDES], { buffer: true }).stdout);
function commitParent(sha) { const r = git(['rev-parse', '--verify', '-q', `${sha}^`], { allowFail: true }); return r.status === 0 ? r.stdout.trim() : EMPTY_TREE; }
const commitHash = (sha) => sha256(git([...DIFF_BASE_ARGS, commitParent(sha), sha, '--', '.', ...HASH_EXCLUDES], { buffer: true }).stdout);
function numstat(args) {
  const out = git(['-c', 'core.quotepath=off', 'diff', '--numstat', '--no-renames', ...args, '--', '.', ...HASH_EXCLUDES]).stdout;
  const files = []; let lines = 0;
  for (const l of out.split('\n').filter(Boolean)) { const [a, d, f] = l.split('\t'); files.push(f); lines += (a === '-' ? 0 : +a) + (d === '-' ? 0 : +d); }
  return { files, lines };
}
const stagedStats = () => numstat(['--cached', baseRef()]);
const commitStats = (sha) => numstat([commitParent(sha), sha]);
function workingStats() {
  const a = numstat([baseRef()]);
  const untracked = git(['ls-files', '--others', '--exclude-standard', '--', '.', ...HASH_EXCLUDES]).stdout.split('\n').filter(Boolean);
  return { files: [...new Set([...a.files, ...untracked])], lines: a.lines };
}
function workingTreeClean() {
  const unstaged = git(['diff', '--quiet', '--', '.', ...HASH_EXCLUDES], { allowFail: true }).status === 0;
  const untracked = git(['ls-files', '--others', '--exclude-standard', '--', '.', ...HASH_EXCLUDES]).stdout.trim() === '';
  return unstaged && untracked;
}
// Testbestand: Pfad + Blob-ID aller Testdateien im Index bzw. im Commit (Tests sind ab Design-Gate eingefroren)
function testsHashFromLines(lines) { return sha256(lines.filter((l) => matchAny(l.split(' ')[0], CFG.testGlobs)).sort().join('\n')); }
function testsHashIndex() {
  const out = git(['-c', 'core.quotepath=off', 'ls-files', '-s']).stdout.split('\n').filter(Boolean);
  return testsHashFromLines(out.map((l) => { const [meta, p] = l.split('\t'); return `${p} ${meta.split(' ')[1]}`; }));
}
function testsHashCommit(sha) {
  const out = git(['-c', 'core.quotepath=off', 'ls-tree', '-r', sha]).stdout.split('\n').filter(Boolean);
  return testsHashFromLines(out.map((l) => { const [meta, p] = l.split('\t'); return `${p} ${meta.split(' ')[2]}`; }));
}

function computeFloor({ files, lines }) {
  const f = CFG.floor; const reasons = []; let floor = 'low';
  const bump = (t, why) => { if (LV(t) > LV(floor)) floor = t; reasons.push(`${t}: ${why}`); };
  for (const file of files) {
    if (matchAny(file, f.highPaths)) bump('high', `kritischer Pfad ${file}`);
    else if (matchAny(file, f.mediumPaths)) bump('medium', `Schnittstellen-/Abhängigkeitspfad ${file}`);
  }
  if (files.length > f.highIfFilesOver) bump('high', `${files.length} Dateien`); else if (files.length > f.mediumIfFilesOver) bump('medium', `${files.length} Dateien`);
  if (lines > f.highIfLinesOver) bump('high', `${lines} Zeilen`); else if (lines > f.mediumIfLinesOver) bump('medium', `${lines} Zeilen`);
  return { floor, reasons };
}

// ------------------------------------------------------------------ Run-State
const statePath = () => path.join(STATE_DIR, 'current.json');
const currentRunId = () => readJSON(statePath(), {})?.runId || null;
const runDir = (id) => path.join(RUNS_DIR, id);
const workDir = (id) => path.join(STATE_DIR, id);
const loadRun = (id = currentRunId()) => (id ? readJSON(path.join(runDir(id), 'run.json')) : null);
const saveRun = (run) => writeJSON(path.join(runDir(run.id), 'run.json'), run);
function requireRun() { const r = loadRun(); if (!r || r.closedAt) fail('Kein aktiver Run. Zuerst: node .quality/bin/qg.mjs init --title "<Auftrag>"'); return r; }
const parseACs = (t) => [...new Set(t.match(/\bAC-\d{3}\b/g) || [])].sort();
const fileHash = (p) => (fs.existsSync(p) ? sha256(fs.readFileSync(p)) : null);
const reqPath = (run) => path.join(runDir(run.id), 'requirements.md');
const designPath = (run) => path.join(runDir(run.id), 'design.md');
const gatePhase = (phase) => (phase === 'impl' ? 'code' : phase);

/** Prüfstand je Phase: woran Verdicts gebunden sind. */
function phaseStand(run, phase = gatePhase(run.phase)) {
  if (phase === 'req') return fileHash(reqPath(run));
  if (phase === 'design') { const d = fileHash(designPath(run)); return d ? sha256(`${stagedHash()}:${d}:${run.reqLock?.hash}`) : null; }
  if (phase === 'code') return stagedHash();
  return null;
}

// ------------------------------------------------------------------ Iterationen & Eskalation
const failedIn = (run, p) => (run.iterations[p] || []).filter((i) => i.result === 'FAIL').length;
const escIn = (run, p) => run.escalations.filter((e) => e.phase === p);
/** Liefert null, wenn eine weitere Prüfrunde zulässig ist, sonst den Sperrgrund. */
function iterationBlock(run, p) {
  const f = failedIn(run, p);
  if (f >= POL.stopAfter) return `${f} Iterationen ohne einheitliches Ergebnis in Phase "${p}" – Stopp, Entscheidung durch den Menschen.`;
  if (f >= POL.mandatoryEscalationAfter && !escIn(run, p).some((e) => e.atFail >= POL.mandatoryEscalationAfter)) {
    if (LV(run.level) >= LEVELS.length - 1) return `Pflicht-Hochsetzung nach ${f} Iterationen nicht möglich (höchste Stufe ${run.level}) – Entscheidung durch den Menschen.`;
    return `Nach ${f} Iterationen ohne einheitliches Ergebnis ist die Hochsetzung Pflicht: node .quality/bin/qg.mjs escalate --reason "…"`;
  }
  return null;
}

// ------------------------------------------------------------------ Rollen
const ROLE_PATTERNS = [
  [new RegExp('^qg-(orchestrator|tiercheck)$'), (m) => ({ kind: m[1] })],
  [new RegExp(`^qg-(req|reqcheck|design|test|impl)-(${LEVEL_RE})$`), (m) => ({ kind: m[1], level: m[2] })],
  [new RegExp(`^qg-rev-([a-z]+)-([ab])-(${LEVEL_RE})$`), (m) => ({ kind: 'rev', domain: m[1], slot: m[2], level: m[3] })],
  [new RegExp(`^qg-arb-([ab])-(${LEVEL_RE})$`), (m) => ({ kind: 'arb', slot: m[1], level: m[2] })],
];
function parseRole(agentType) {
  if (!agentType) return { kind: 'human' };
  for (const [re, fn] of ROLE_PATTERNS) { const m = re.exec(agentType); if (m) return { ...fn(m), name: agentType }; }
  return agentType.startsWith('qg-') ? { kind: 'invalid', name: agentType } : { kind: 'foreign', name: agentType };
}
const isQg = (r) => !['human', 'foreign'].includes(r.kind);
const CHECKER_KINDS = new Set(['rev', 'arb', 'reqcheck', 'tiercheck']);

// ------------------------------------------------------------------ Ausgabe
function fail(msg, code = 1) { process.stderr.write(`QG: ${msg}\n`); process.exit(code); }
function block(msg) { process.stderr.write(`QG-GUARD: ${msg}\n`); process.exit(2); }
function ok(msg) { if (msg) process.stdout.write(msg + '\n'); process.exit(0); }
function readStdin() { try { return fs.readFileSync(0, 'utf8'); } catch { return ''; } }
const argVal = (a, n, d = null) => { const i = a.indexOf(n); return i >= 0 && a[i + 1] !== undefined ? a[i + 1] : d; };

// ------------------------------------------------------------------ Shell
function splitShell(cmd) {
  const t = []; let cur = ''; let q = null; let has = false;
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i];
    if (q) { if (c === q) q = null; else if (c === '\\' && q === '"' && i + 1 < cmd.length) cur += cmd[++i]; else cur += c; continue; }
    if (c === '"' || c === "'") { q = c; has = true; continue; }
    if (/\s/.test(c)) { if (cur || has) t.push(cur); cur = ''; has = false; continue; }
    cur += c;
  }
  if (cur || has) t.push(cur);
  return t;
}
const stripQuoted = (c) => c.replace(/'[^']*'/g, "''").replace(/"(?:\\.|[^"\\])*"/g, '""');

// ------------------------------------------------------------------ Verdict-Blöcke
function extractBlock(text, tag) {
  if (!text) return null;
  const re = new RegExp(`<<<${tag}\\s*([\\s\\S]*?)\\s*${tag}>>>`, 'g'); let m, last = null;
  while ((m = re.exec(text))) last = m[1];
  if (!last) return null;
  try { return JSON.parse(last.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '')); } catch { return { __parseError: true }; }
}
function normalizeVerdict(v, domain, run) {
  const errors = []; const notes = [];
  const findings = Array.isArray(v?.findings) ? v.findings : (errors.push('findings fehlt (Array)'), []);
  findings.forEach((f, i) => {
    if (!f.id) f.id = `F-${i + 1}`;
    f.severity = String(f.severity || '').toUpperCase();
    if (!SEVERITIES.has(f.severity)) errors.push(`${f.id}: ungültige severity "${f.severity}"`);
    if (!f.title) errors.push(`${f.id}: title fehlt`);
  });
  let computed = findings.some((f) => BLOCKING.has(f.severity)) ? 'FAIL' : 'PASS';
  if (domain === 'acceptance') {
    const res = Array.isArray(v?.ac_results) ? v.ac_results : (errors.push('ac_results fehlt (Array)'), []);
    for (const ac of run?.reqLock?.acs || []) {
      const r = res.find((x) => x.ac === ac);
      if (!r) { computed = 'FAIL'; notes.push(`${ac} ohne Ergebnis`); }
      else if (String(r.status).toUpperCase() !== 'PASS') { computed = 'FAIL'; notes.push(`${ac} = ${r.status}`); }
      else if (!r.evidence) { computed = 'FAIL'; notes.push(`${ac} ohne Nachweis`); }
    }
  }
  const claimed = String(v?.result || '').toUpperCase();
  if (claimed && claimed !== computed) notes.push(`gemeldet ${claimed}, berechnet ${computed} (berechnet gilt)`);
  return { errors, computed, notes, findings };
}
function modelsFromTranscript(p) {
  const s = new Set();
  try {
    for (const line of fs.readFileSync(p, 'utf8').split('\n')) {
      if (!line.includes('"model"')) continue;
      try { const o = JSON.parse(line); const m = o?.message?.model || o?.model; if (typeof m === 'string' && m.startsWith('claude')) s.add(m); } catch { /* */ }
    }
  } catch { /* */ }
  return [...s];
}
const modelMatches = (a, e) => !!a && (a === e || a.startsWith(e));

// ------------------------------------------------------------------ Evidence-Reader
function fsReader(base) {
  return { list: (d) => { try { return fs.readdirSync(path.join(base, d)); } catch { return []; } },
    read: (f) => { try { return fs.readFileSync(path.join(base, f), 'utf8'); } catch { return null; } } };
}
function gitReader(sha, base) {
  return { list: (d) => { const r = git(['ls-tree', '--name-only', `${sha}:${base}/${d}`], { allowFail: true }); return r.status === 0 ? r.stdout.split('\n').filter(Boolean) : []; },
    read: (f) => { const r = git(['show', `${sha}:${base}/${f}`], { allowFail: true }); return r.status === 0 ? r.stdout : null; } };
}
const jsonList = (ev, dir) => ev.list(dir).filter((f) => f.endsWith('.json')).map((f) => JSON.parse(ev.read(`${dir}/${f}`)));

// ------------------------------------------------------------------ Gate-Auswertung (rein)
/**
 * Bewertet eine Phase gegen einen Prüfstand. complete=false: nicht alle Prüfer haben gültig gemeldet (keine Iteration).
 */
function evaluatePhase({ phase, run, stand, level, ev, checksKey }) {
  const reasons = []; const domains = {}; let complete = true;
  const pc = CFG.phases[phase];
  if (checksKey !== undefined) {
    const checks = JSON.parse(ev.read(`checks-${phase}-${short(checksKey)}.json`) || 'null');
    if (!checks || checks.key !== checksKey) { reasons.push('Deterministische Checks fehlen für diesen Stand'); complete = false; }
    else if (!checks.pass) reasons.push(`Deterministische Checks rot: ${checks.results.filter((r) => r.required && !r.pass).map((r) => r.id).join(', ')}`);
  }
  const verdicts = jsonList(ev, 'verdicts').filter((v) => v.phase === phase && v.stand === stand && v.level === level);
  const rulings = jsonList(ev, 'rulings').filter((r) => r.phase === phase && r.stand === stand && r.valid);
  const models = {};
  for (const line of (ev.read('agents.log.jsonl') || '').split('\n').filter(Boolean)) {
    try { const o = JSON.parse(line); if (o.agentId && o.resolvedModel) (models[o.agentId] ||= new Set()).add(o.resolvedModel); } catch { /* */ }
  }
  const expected = LEVEL(level).model;
  const overruled = (d, s, fid) => ['a', 'b'].every((as) => rulings.some((r) => r.arbSlot === as && r.items.some((it) => it.domain === d && it.slot === s && it.finding === fid && it.decision === 'FALSE_POSITIVE')));
  for (const d of pc.domains) {
    domains[d] = {};
    for (const s of pc.slots) {
      const cand = verdicts.filter((v) => v.domain === d && v.slot === s).sort((a, b) => (a.recordedAt < b.recordedAt ? 1 : -1));
      const v = cand.find((x) => x.valid) || cand[0];
      const tag = `${d}/${s.toUpperCase()}`;
      if (!v) { domains[d][s] = 'FEHLT'; complete = false; reasons.push(`${tag}: kein Ergebnis für diesen Stand/diese Stufe`); continue; }
      if (!v.valid) { domains[d][s] = 'UNGÜLTIG'; complete = false; reasons.push(`${tag}: ungültig (${v.invalidReason})`); continue; }
      const evm = new Set([...(v.transcriptModels || []), ...(models[v.agentId] ? [...models[v.agentId]] : [])]);
      if (CFG.requireModelEvidence) {
        if (!evm.size) { domains[d][s] = 'MODELL?'; complete = false; reasons.push(`${tag}: Modell nicht nachweisbar`); continue; }
        const bad = [...evm].filter((m) => !modelMatches(m, expected));
        if (bad.length) { domains[d][s] = 'MODELL✗'; complete = false; reasons.push(`${tag}: falsches Modell ${bad.join(',')} (erwartet ${expected})`); continue; }
      }
      if (CFG.requireEffortMatch && v.effortObserved && v.effortObserved !== LEVEL(level).effort) { domains[d][s] = 'EFFORT✗'; complete = false; reasons.push(`${tag}: Effort ${v.effortObserved}`); continue; }
      if (v.result === 'PASS') { domains[d][s] = 'PASS'; continue; }
      const open = v.findings.filter((f) => BLOCKING.has(f.severity) && !overruled(d, s, f.id));
      const accOpen = d === 'acceptance' && v.notes?.some((n) => /AC-\d{3}/.test(n));
      if (!open.length && !accOpen) { domains[d][s] = 'PASS*'; continue; }
      domains[d][s] = 'FAIL'; reasons.push(`${tag}: ${open.length} offene Befunde${accOpen ? ' + Abnahmekriterien offen' : ''}`);
    }
  }
  return { phase, pass: reasons.length === 0, complete, reasons, domains, stand, level };
}

function liveEvaluate(run) {
  const phase = gatePhase(run.phase);
  if (!['req', 'design', 'code'].includes(phase)) return { phase, pass: false, complete: false, reasons: [`Phase "${run.phase}" hat kein Gate`], domains: {} };
  const stand = phaseStand(run, phase);
  const ev = fsReader(workDir(run.id));
  const res = evaluatePhase({ phase, run, stand, level: run.level, ev, checksKey: phase === 'req' ? undefined : stagedHash() });
  const pre = [];
  if (phase !== 'req') {
    if (!run.reqLock) pre.push('Anforderungen nicht freigegeben');
    else if (fileHash(reqPath(run)) !== run.reqLock.hash) pre.push('requirements.md nach Freigabe verändert');
  }
  if (phase === 'design' && !fs.existsSync(designPath(run))) pre.push('design.md fehlt');
  if (phase === 'code') {
    if (!run.designGate) pre.push('Keine Freigabe zur Implementierung (Design-Gate)');
    else {
      if (fileHash(designPath(run)) !== run.designGate.designHash) pre.push('design.md nach Freigabe verändert');
      if (testsHashIndex() !== run.designGate.testsHash) pre.push('Tests nach Freigabe zur Implementierung verändert → design reopen');
    }
    const fl = computeFloor(stagedStats());
    if (LV(fl.floor) > LV(run.tier)) pre.push(`Komplexität ${run.tier} < Mindeststufe ${fl.floor} (${fl.reasons.join('; ')}) → tier set`);
  }
  res.reasons.unshift(...pre); res.pass = res.pass && !pre.length;
  return res;
}

// ------------------------------------------------------------------ Checks
function walk(dir, acc = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (CFG.walkIgnore.includes(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, acc); else acc.push(rel(p));
  }
  return acc;
}
function builtinTraceability(run) {
  const acs = run.reqLock?.acs || []; const map = Object.fromEntries(acs.map((a) => [a, []]));
  for (const f of walk(ROOT).filter((x) => matchAny(x, CFG.testGlobs))) {
    const txt = fs.readFileSync(path.join(ROOT, f), 'utf8');
    for (const ac of acs) if (txt.includes(ac)) map[ac].push(f);
  }
  const missing = acs.filter((a) => !map[a].length);
  return { pass: acs.length > 0 && !missing.length, output: missing.length ? `Ohne Test: ${missing.join(', ')}` : `Alle ${acs.length} AC mit Tests verknüpft`, map };
}

// ------------------------------------------------------------------ Befehle
const commands = {};

commands.init = (args) => {
  const title = argVal(args, '--title'); if (!title) fail('--title "<Auftrag>" fehlt');
  const cur = loadRun(); if (cur && !cur.closedAt && !args.includes('--force')) fail(`Run ${cur.id} ist noch offen (finalize/commit oder abort).`);
  const slug = title.toLowerCase().normalize('NFKD').replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '-').slice(0, 40) || 'run';
  const id = `${new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, '').replace('T', '-')}-${slug}`;
  saveRun({ id, title, createdAt: now(), kitVersion: CFG.version, phase: 'tier', tier: null, level: null, tierHistory: [], levelHistory: [],
    tierCheck: null, reqLock: null, designGate: null, codeGate: null, iterations: { req: [], design: [], code: [] }, escalations: [], closedAt: null });
  fs.mkdirSync(workDir(id), { recursive: true });
  writeJSON(statePath(), { runId: id, startedAt: now() });
  ok(`Run angelegt: ${id}\nNächster Schritt: qg-tiercheck (unabhängige Komplexitätsbewertung) starten, eigene Bewertung bilden, dann "tier set".`);
};

commands.abort = (args) => {
  const run = requireRun(); const why = argVal(args, '--reason'); if (!why) fail('--reason fehlt');
  run.closedAt = now(); run.aborted = why; saveRun(run);
  appendLog(path.join(STATE_DIR, 'history.jsonl'), { runId: run.id, aborted: why }); fs.rmSync(statePath(), { force: true });
  ok(`Run ${run.id} abgebrochen.`);
};

commands.metrics = () => { const st = workingStats(); const fl = computeFloor(st); ok(JSON.stringify({ files: st.files.length, lines: st.lines, floor: fl.floor, reasons: fl.reasons }, null, 2)); };

commands.tier = (args) => {
  const run = requireRun(); const [sub, t] = args;
  if (sub !== 'set' || !CFG.complexityTiers.includes(t)) fail('Aufruf: tier set <low|medium|high> --reason "<Rubrikpunkte>"');
  const reason = argVal(args, '--reason'); if (!reason) fail('--reason fehlt');
  if (!run.tierCheck) fail('Unabhängige Gegenprüfung der Komplexität fehlt (qg-tiercheck).');
  if (run.tier && LV(t) < LV(run.tier)) fail(`Herabstufen verboten (${run.tier} → ${t}).`);
  const fl = computeFloor(workingStats());
  const min = [fl.floor, run.tierCheck.tier].sort((a, b) => LV(b) - LV(a))[0];
  if (LV(t) < LV(min)) fail(`Stufe ${t} liegt unter max(Mindeststufe ${fl.floor}, Gegenprüfung ${run.tierCheck.tier}) = ${min}. Bei Abweichung gilt die höhere Bewertung.`);
  const prev = run.tier; run.tier = t;
  run.tierHistory.push({ at: now(), from: prev, to: t, reason, floor: fl.floor, tierCheck: run.tierCheck.tier });
  const prevLevel = run.level;
  if (!run.level || LV(t) > LV(run.level)) { run.level = t; run.levelHistory.push({ at: now(), from: prevLevel, to: t, cause: 'Komplexität' }); }
  if (run.phase === 'tier') run.phase = 'req';
  saveRun(run);
  ok(`Komplexität ${t}${prev ? ` (vorher ${prev})` : ''}. Ausführungsstufe ${run.level}: ${LEVEL(run.level).label}.${prevLevel && prevLevel !== run.level ? ' Bisherige Prüfergebnisse sind ungültig.' : ''}`);
};

commands.escalate = (args) => {
  const run = requireRun(); const reason = argVal(args, '--reason'); if (!reason) fail('--reason fehlt');
  const p = gatePhase(run.phase); if (!run.iterations[p]) fail(`In Phase "${run.phase}" gibt es keine Prüfiterationen.`);
  const f = failedIn(run, p); const esc = escIn(run, p);
  const firstWindow = f >= POL.optionalEscalationAfter && f < POL.mandatoryEscalationAfter && !esc.some((e) => e.atFail >= POL.optionalEscalationAfter && e.atFail < POL.mandatoryEscalationAfter);
  const secondWindow = f >= POL.mandatoryEscalationAfter && f < POL.stopAfter && !esc.some((e) => e.atFail >= POL.mandatoryEscalationAfter);
  if (!firstWindow && !secondWindow) fail(`Hochsetzung nicht zulässig: ${f} Iterationen ohne einheitliches Ergebnis in "${p}". Erlaubt nach ${POL.optionalEscalationAfter} (optional) und nach ${POL.mandatoryEscalationAfter} (Pflicht), je einmal.`);
  if (LV(run.level) >= LEVELS.length - 1) fail(`Höchste Stufe ${run.level} erreicht – Entscheidung durch den Menschen.`);
  const from = run.level; run.level = LEVELS[LV(from) + 1];
  run.escalations.push({ at: now(), phase: p, atFail: f, from, to: run.level, reason, mandatory: secondWindow });
  run.levelHistory.push({ at: now(), from, to: run.level, cause: `Eskalation ${p} nach ${f} Iterationen` });
  saveRun(run);
  ok(`Stufe ${from} → ${run.level}: ${LEVEL(run.level).label}. Alle Agenten der Phase laufen ab jetzt auf dieser Stufe.`);
};

commands.req = (args) => {
  const run = requireRun();
  if (args[0] !== 'lock') fail('Aufruf: req lock --approved-by "<Name>"');
  if (run.phase !== 'req') fail(`Phase ist "${run.phase}", nicht "req".`);
  const by = argVal(args, '--approved-by'); if (!by) fail('--approved-by fehlt');
  const p = reqPath(run); if (!fs.existsSync(p)) fail('requirements.md fehlt');
  const txt = fs.readFileSync(p, 'utf8'); const acs = parseACs(txt);
  if (!acs.length) fail('Keine Abnahmekriterien (AC-001 …)');
  const g = liveEvaluate(run);
  if (!g.pass) fail(`Gegenprüfung der Anforderungen nicht bestanden:\n${g.reasons.join('\n')}`);
  const open = (txt.match(/^\s*[-*]?\s*\*{0,2}Q-\d{2}\b.*$/gm) || []).filter((l) => !/(beantwortet|answered|erledigt)/i.test(l));
  if (open.length) fail(`Offene Fragen:\n${open.join('\n')}`);
  run.reqLock = { hash: sha256(txt), acs, approvedBy: by, at: now(), version: (run.reqLock?.version || 0) + 1, level: run.level };
  run.phase = 'design'; saveRun(run);
  ok(`Anforderungen v${run.reqLock.version} freigegeben (${acs.length} AC) durch ${by}. Phase: design (Lösungsentwurf + Tests).`);
};

commands.design = (args) => {
  const run = requireRun();
  if (args[0] !== 'reopen') fail('Aufruf: design reopen --reason "<Grund>"');
  const reason = argVal(args, '--reason'); if (!reason) fail('--reason fehlt');
  if (!['impl', 'code'].includes(run.phase)) fail('Nur nach Freigabe zur Implementierung möglich.');
  run.designGate = null; run.phase = 'design'; run.reopened = [...(run.reopened || []), { at: now(), reason }];
  saveRun(run); ok('Design-Phase wieder geöffnet. Tests/Entwurf dürfen angepasst werden; danach erneut Design-Gate.');
};

commands.stage = () => {
  const run = requireRun();
  if (!['design', 'impl', 'code'].includes(run.phase)) fail(`In Phase "${run.phase}" wird nicht gestaged.`);
  if (git(['check-ignore', '-q', '.quality/state/current.json'], { allowFail: true }).status !== 0) fail('.quality/state/ fehlt in .gitignore (doctor).');
  git(['add', '-A', '--', '.', ':(exclude).quality/runs']);
  if (run.phase === 'design') {
    const nonTest = stagedStats().files.filter((f) => !matchAny(f, CFG.testGlobs));
    if (nonTest.length) fail(`Vor der Freigabe zur Implementierung sind nur Tests erlaubt. Nicht-Test-Änderungen: ${nonTest.slice(0, 10).join(', ')}`);
  }
  if (run.phase === 'impl') { run.phase = 'code'; saveRun(run); }
  const p = gatePhase(run.phase);
  ok(`Gestaged. Phase ${p}, Prüfstand ${short(phaseStand(run, p))}, Stufe ${run.level}, Iterationen ohne Einigung: ${failedIn(run, p)}.`);
};

commands.checks = () => {
  const run = requireRun(); const phase = gatePhase(run.phase);
  if (!['design', 'code'].includes(phase)) fail(`Keine Checks in Phase "${run.phase}".`);
  if (!workingTreeClean()) fail('Ungestagte Änderungen. Zuerst "stage".');
  const key = stagedHash(); const results = [];
  for (const c of phase === 'design' ? CFG.designChecks : CFG.checks) {
    const t0 = Date.now();
    if (c.builtin === 'traceability') { const r = builtinTraceability(run); results.push({ id: c.id, required: c.required, pass: r.pass, ms: Date.now() - t0, output: r.output, map: r.map }); continue; }
    const r = spawnSync(c.cmd, { cwd: ROOT, shell: true, encoding: 'utf8', timeout: (CFG.checkTimeoutSec || 1800) * 1000, maxBuffer: 256 * 1024 * 1024 });
    const okExit = c.expect === 'fail' ? r.status !== 0 && r.status !== null : r.status === 0;
    results.push({ id: c.id, cmd: c.cmd, required: c.required, expect: c.expect || 'pass', pass: okExit, exit: r.status, ms: Date.now() - t0, output: `${r.stdout || ''}${r.stderr || ''}`.slice(-4000) });
  }
  if (stagedHash() !== key) fail('Stand hat sich während der Checks verändert – erneut stagen.');
  const pass = results.every((r) => r.pass || !r.required);
  writeJSON(path.join(workDir(run.id), `checks-${phase}-${short(key)}.json`), { phase, key, at: now(), pass, results });
  process.stdout.write(results.map((r) => `${r.pass ? '✔' : r.required ? '✖' : '!'} ${r.id}${r.expect === 'fail' ? ' (muss rot sein)' : ''}${r.pass ? '' : ' :: ' + (r.output || '').split('\n').filter(Boolean).slice(-4).join(' | ')}`).join('\n') + `\nChecks ${phase} ${pass ? 'GRÜN' : 'ROT'} (${short(key)})\n`);
  process.exit(pass ? 0 : 1);
};

commands.gate = () => {
  const run = requireRun(); const res = liveEvaluate(run); const p = res.phase;
  if (!['req', 'design', 'code'].includes(p)) fail(res.reasons.join('; '));
  // Iteration zählen: nur vollständige Runden; je Prüfstand und Stufe einmal
  const its = run.iterations[p];
  const known = its.find((i) => i.stand === res.stand && i.level === res.level);
  if (res.complete && !known) its.push({ n: its.length + 1, stand: res.stand, level: res.level, result: res.pass ? 'PASS' : 'FAIL', at: now() });
  else if (known && res.pass && known.result === 'FAIL') { known.result = 'PASS'; known.resolvedBy = 'Schiedsspruch A+B'; known.resolvedAt = now(); }
  if (res.pass && p === 'design') {
    run.designGate = { stand: res.stand, stagedHash: stagedHash(), testsHash: testsHashIndex(), designHash: fileHash(designPath(run)), level: run.level, at: now() };
    run.phase = 'impl';
    writeJSON(path.join(workDir(run.id), 'design-gate.json'), { ...res, ...run.designGate, evaluatedAt: now() });
  }
  if (res.pass && p === 'code') { run.codeGate = { stand: res.stand, level: run.level, at: now() }; writeJSON(path.join(workDir(run.id), 'gate.json'), { ...res, evaluatedAt: now(), runId: run.id }); }
  saveRun(run);
  const f = failedIn(run, p); const blockMsg = iterationBlock(run, p);
  const label = { req: 'Anforderungs-Gate', design: 'Design-Gate (Freigabe zur Implementierung)', code: 'Code-Gate' }[p];
  const tbl = Object.entries(res.domains).map(([d, s]) => `  ${d.padEnd(12)} ${Object.entries(s).map(([k, v]) => `${k.toUpperCase()}=${v}`).join('  ')}`).join('\n');
  let hint = '';
  if (!res.pass && res.complete) {
    hint = `\nIterationen ohne einheitliches Ergebnis in "${p}": ${f}.`;
    if (blockMsg) hint += `\n→ ${blockMsg}`;
    else if (f >= POL.optionalEscalationAfter && !escIn(run, p).length) hint += `\n→ Hochsetzung auf die nächste Stufe ist jetzt möglich (optional): qg escalate --reason "…"`;
  }
  if (!res.complete && !res.pass) hint = '\n(Runde unvollständig – zählt nicht als Iteration)';
  process.stdout.write(`${label}: ${res.pass ? 'BESTANDEN' : 'NICHT BESTANDEN'} | Stand ${short(res.stand)} | Stufe ${run.level}\n${tbl}\n${res.reasons.map((r) => '  - ' + r).join('\n')}${hint}\n`);
  if (res.pass && p === 'design') process.stdout.write('→ Freigabe zur Implementierung erteilt. Tests und Entwurf sind eingefroren.\n');
  process.exit(res.pass ? 0 : 1);
};

commands.finalize = () => {
  const run = requireRun();
  if (gatePhase(run.phase) !== 'code') fail('Finalisieren nur nach Code-Gate.');
  const res = liveEvaluate(run); if (!res.pass) fail(`Code-Gate nicht bestanden:\n${res.reasons.join('\n')}`);
  const dst = path.join(runDir(run.id), 'evidence');
  fs.rmSync(dst, { recursive: true, force: true });
  fs.cpSync(workDir(run.id), dst, { recursive: true, filter: (p) => !p.endsWith('.lock') });
  const gate = { ...res, evaluatedAt: now(), runId: run.id, designGate: run.designGate };
  writeJSON(path.join(runDir(run.id), 'gate.json'), gate);
  fs.writeFileSync(path.join(runDir(run.id), 'report.md'), renderReport(run, gate));
  git(['add', '-f', '--', `.quality/runs/${run.id}`]);
  ok(`Freigegeben. Nachweise: .quality/runs/${run.id}/\nCommit: git commit -m "<type>(<scope>): <Zusammenfassung>"  (Trailer ergänzt der Hook)`);
};

function renderReport(run, gate) {
  const ev = fsReader(workDir(run.id)); const L = [];
  const vAll = jsonList(ev, 'verdicts'); const rAll = jsonList(ev, 'rulings');
  const checksCode = JSON.parse(ev.read(`checks-code-${short(gate.stand)}.json`) || '{}');
  const trace = checksCode.results?.find((r) => r.id === 'traceability')?.map || {};
  L.push(`# Quality-Gate-Bericht — ${run.title}`, '', '| Feld | Wert |', '|---|---|',
    `| Run | \`${run.id}\` |`, `| Komplexität | **${run.tier}** (Gegenprüfung: ${run.tierCheck?.tier}) |`,
    `| Ausführungsstufe am Ende | **${run.level}** – ${LEVEL(run.level).label} (${LEVEL(run.level).model} / ${LEVEL(run.level).effort}) |`,
    `| Anforderungen | v${run.reqLock.version}, ${run.reqLock.acs.length} AC, freigegeben von ${run.reqLock.approvedBy} (${run.reqLock.at}) |`,
    `| Freigabe zur Implementierung | ${run.designGate.at}, Stufe ${run.designGate.level} |`,
    `| Code-Gate | BESTANDEN ${gate.evaluatedAt}, Stand \`${gate.stand}\` |`, '');
  L.push('## Iterationen und Eskalation', '', '| Phase | Iterationen gesamt | davon ohne Einigung | Hochsetzungen |', '|---|---|---|---|');
  for (const p of ['req', 'design', 'code']) L.push(`| ${p} | ${run.iterations[p].length} | ${failedIn(run, p)} | ${escIn(run, p).map((e) => `${e.from}→${e.to} nach ${e.atFail}${e.mandatory ? ' (Pflicht)' : ''}`).join(', ') || '—'} |`);
  L.push('', '### Stufenverlauf', '', ...run.levelHistory.map((h) => `- ${h.at}: ${h.from || '—'} → **${h.to}** (${h.cause})`), '');
  for (const [p, stand, level] of [['req', run.reqLock.hash, run.reqLock.level], ['design', run.designGate.stand, run.designGate.level], ['code', gate.stand, gate.level]]) {
    L.push(`## Gegenprüfung Phase „${p}“ (Stufe ${level})`, '', '| Domäne | Slot | Ergebnis | Agent | Modell | B/M/m/i |', '|---|---|---|---|---|---|');
    for (const v of vAll.filter((x) => x.phase === p && x.stand === stand && x.level === level && x.valid)) {
      const c = (s) => v.findings.filter((f) => f.severity === s).length;
      const gd = (p === 'design' ? JSON.parse(ev.read('design-gate.json') || '{}').domains : p === 'code' ? gate.domains : null)?.[v.domain]?.[v.slot];
      const shown = v.result === 'FAIL' && gd === 'PASS*' ? 'FAIL → widerlegt (Arbiter A+B)' : v.result;
      L.push(`| ${v.domain} | ${v.slot.toUpperCase()} | ${shown} | \`${v.agentType}\` | ${(v.transcriptModels || []).join(', ') || '—'} | ${c('BLOCKER')}/${c('MAJOR')}/${c('MINOR')}/${c('INFO')} |`);
    }
    L.push('');
  }
  const rs = rAll.filter((r) => r.valid);
  if (rs.length) { L.push('## Schiedssprüche (Arbiter A + B)', ''); for (const r of rs) for (const it of r.items) L.push(`- [${r.phase}, Arbiter ${r.arbSlot.toUpperCase()}] ${it.domain}/${it.slot.toUpperCase()} ${it.finding}: **${it.decision}** — ${it.reason}`); L.push(''); }
  L.push('## Rückverfolgbarkeit AC → Test', '', '| AC | Testdateien |', '|---|---|', ...run.reqLock.acs.map((a) => `| ${a} | ${(trace[a] || []).map((f) => `\`${f}\``).join(', ') || '—'} |`), '');
  const acc = vAll.filter((v) => v.phase === 'code' && v.domain === 'acceptance' && v.stand === gate.stand && v.valid);
  L.push('## Abnahme nach der Implementierung', '', '| AC | Prüfer A | Prüfer B |', '|---|---|---|');
  for (const a of run.reqLock.acs) { const g = (s) => acc.find((v) => v.slot === s)?.raw?.ac_results?.find((r) => r.ac === a); const fm = (r) => (r ? `${r.status} — ${String(r.evidence).slice(0, 100)}` : '—'); L.push(`| ${a} | ${fm(g('a'))} | ${fm(g('b'))} |`); }
  const infos = vAll.filter((v) => v.stand === gate.stand && v.valid).flatMap((v) => v.findings.filter((f) => f.severity === 'INFO').map((f) => `- [${v.domain}/${v.slot.toUpperCase()}] ${f.title}`));
  L.push('', '## Hinweise (INFO)', '', ...(infos.length ? infos : ['- keine']), '', '---', '_Erzeugt von qg.mjs v2. Nachweise unter `evidence/`. Prüfbar mit `node .quality/bin/qg.mjs verify-commit <sha>`._', '');
  return L.join('\n');
}

commands.status = () => {
  const run = loadRun(); if (!run || run.closedAt) ok('Kein aktiver Run.');
  const p = gatePhase(run.phase);
  ok([`Run: ${run.id} — ${run.title}`, `Phase: ${run.phase}`, `Komplexität: ${run.tier || '—'} | Gegenprüfung: ${run.tierCheck?.tier || '—'}`,
    `Ausführungsstufe: ${run.level ? `${run.level} (${LEVEL(run.level).label})` : '—'}`,
    `Anforderungen: ${run.reqLock ? `v${run.reqLock.version}, ${run.reqLock.acs.length} AC` : 'nicht freigegeben'}`,
    `Freigabe zur Implementierung: ${run.designGate ? run.designGate.at : 'nein'}`,
    `Iterationen ohne Einigung: req ${failedIn(run, 'req')} · design ${failedIn(run, 'design')} · code ${failedIn(run, 'code')}`,
    `Sperre: ${run.iterations[p] ? iterationBlock(run, p) || 'keine' : '—'}`].join('\n'));
};

// ------------------------------------------------------------------ verify
function verifyStaged() {
  const id = currentRunId(); if (!id) return { ok: false, why: 'Kein aktiver Quality-Gate-Run (claude --agent qg-orchestrator).' };
  const gate = readJSON(path.join(runDir(id), 'gate.json')); if (!gate) return { ok: false, why: `Run ${id} nicht finalisiert.` };
  const h = stagedHash();
  if (gate.stand !== h) return { ok: false, why: `Gestagter Stand ${short(h)} ≠ freigegebener Stand ${short(gate.stand)}.` };
  if (!gate.pass) return { ok: false, why: 'Code-Gate nicht bestanden.' };
  return { ok: true, id, hash: h };
}
commands['verify-staged'] = () => { const r = verifyStaged(); if (r.ok) ok(`OK ${r.id} ${short(r.hash)}`); fail(r.why); };

commands['verify-commit'] = (args) => {
  const sha = git(['rev-parse', args[0] || 'HEAD']).stdout.trim();
  if (git(['rev-list', '--parents', '-n', '1', sha]).stdout.trim().split(' ').length > 2) ok(`${short(sha)}: Merge-Commit – übersprungen.`);
  const changed = git(['diff-tree', '--no-commit-id', '--name-only', '-r', '--no-renames', sha]).stdout.split('\n').filter(Boolean);
  if (!changed.some((f) => !f.startsWith('.quality/runs/') && !f.startsWith('.quality/state/'))) ok(`${short(sha)}: nur Nachweise – OK.`);
  const gates = changed.filter((f) => /^\.quality\/runs\/[^/]+\/gate\.json$/.test(f));
  if (gates.length !== 1) fail(`${short(sha)}: ${gates.length} Gate-Nachweise (erwartet 1).`);
  const runId = gates[0].split('/')[2]; const base = `.quality/runs/${runId}`; const rd = gitReader(sha, base); const ev = gitReader(sha, `${base}/evidence`);
  const run = JSON.parse(rd.read('run.json') || 'null'); const gate = JSON.parse(rd.read('gate.json') || 'null');
  const h = commitHash(sha); const reasons = [];
  if (!run || !gate) fail(`${short(sha)}: run.json/gate.json fehlt.`);
  if (gate.stand !== h) reasons.push(`Commit-Diff ${short(h)} ≠ Gate-Stand ${short(gate.stand)}`);
  if (sha256(rd.read('requirements.md') || '') !== run.reqLock?.hash) reasons.push('requirements.md ≠ Freigabe');
  if (sha256(rd.read('design.md') || '') !== run.designGate?.designHash) reasons.push('design.md ≠ Freigabe');
  if (testsHashCommit(sha) !== run.designGate?.testsHash) reasons.push('Tests ≠ Stand der Freigabe zur Implementierung');
  const fl = computeFloor(commitStats(sha)); if (LV(fl.floor) > LV(run.tier)) reasons.push(`Komplexität ${run.tier} < Mindeststufe ${fl.floor}`);
  for (const [phase, stand, level, key] of [['req', run.reqLock?.hash, run.reqLock?.level, undefined], ['design', run.designGate?.stand, run.designGate?.level, run.designGate?.stagedHash], ['code', h, gate.level, h]]) {
    const r = evaluatePhase({ phase, run, stand, level, ev, checksKey: key });
    if (!r.pass) reasons.push(...r.reasons.map((x) => `[${phase}] ${x}`));
  }
  if (reasons.length) fail(`${short(sha)}: Nachprüfung negativ:\n${reasons.join('\n')}`);
  ok(`${short(sha)}: Quality-Gate nachgewiesen (Run ${runId}, Komplexität ${run.tier}, Stufe ${gate.level}).`);
};

// ------------------------------------------------------------------ Hooks
const hooks = {};
hooks['session-start'] = () => {
  const m = [];
  if (git(['config', '--get', 'core.hooksPath'], { allowFail: true }).stdout.trim() !== '.githooks') m.push('WARNUNG: core.hooksPath ≠ .githooks – Commit-Schutz inaktiv (qg.mjs doctor).');
  if (process.env.CLAUDE_CODE_SUBAGENT_MODEL_FORCE) m.push('WARNUNG: CLAUDE_CODE_SUBAGENT_MODEL_FORCE gesetzt – Stufenmodelle werden überschrieben.');
  const run = loadRun(); if (run && !run.closedAt) m.push(`Aktiver Run ${run.id}: Phase ${run.phase}, Stufe ${run.level || '—'}. Status: node .quality/bin/qg.mjs status`);
  if (m.length) process.stdout.write(m.join('\n') + '\n'); process.exit(0);
};

hooks['pre-tool'] = () => {
  let input; try { input = JSON.parse(readStdin() || '{}'); } catch { block('Hook-Eingabe nicht lesbar (fail-closed).'); }
  const role = parseRole(input.agent_type);
  if (role.kind === 'invalid') block(`Unbekannter qg-Agent ${role.name}.`);
  try { preToolGuard(input, role); }
  catch (e) { if (isQg(role)) block(`Guard-Fehler (fail-closed): ${e.message}`); process.stderr.write(`QG-GUARD Warnung: ${e.message}\n`); }
  process.exit(0);
};

function preToolGuard(input, role) {
  const tool = input.tool_name; const ti = input.tool_input || {};
  const admin = role.kind === 'human' && process.env.QG_ADMIN === '1';
  if (tool === 'Agent' || tool === 'Task') return spawnGuard(ti, role);
  if (['Write', 'Edit', 'MultiEdit', 'NotebookEdit'].includes(tool)) return writeGuard(ti.file_path || ti.notebook_path, role, admin);
  if (['Read', 'Grep', 'Glob', 'LS'].includes(tool)) return readGuard(ti.file_path || ti.path || ti.pattern, role);
  if (tool === 'Bash' || tool === 'PowerShell') return bashGuard(String(ti.command || ''), role, admin);
  if (/^(WebFetch|WebSearch)$/.test(tool) && isQg(role)) block(`${tool} ist für Quality-Gate-Agenten gesperrt.`);
}

function spawnGuard(ti, role) {
  const t = parseRole(ti.subagent_type);
  if (role.kind !== 'orchestrator') {
    if (isQg(t)) block('Quality-Gate-Agenten startet nur der qg-orchestrator.');
    if (isQg(role)) block('Unteragenten dürfen keine Agenten starten.');
    return;
  }
  if (!isQg(t) || t.kind === 'invalid' || t.kind === 'orchestrator') block(`Der Orchestrator startet nur qg-Agenten (angefragt: ${ti.subagent_type || 'general-purpose'}).`);
  if (ti.model) block('Modell-Override verboten – Modell kommt aus der Agentendefinition der Stufe.');
  if (ti.effort) block('Effort-Override verboten – Effort kommt aus der Agentendefinition der Stufe.');
  if (ti.isolation) block('isolation-Override nicht vorgesehen.');
  const run = loadRun(); if (!run || run.closedAt) block('Kein aktiver Run (qg init).');
  const wd = workDir(run.id);
  if (t.kind === 'tiercheck') {
    if (run.tier) block('Komplexität ist bereits festgelegt; eine Neubewertung kann nur anheben (tier set).');
    if (!createOnce(path.join(wd, 'spawns', 'tiercheck.lock'), now()) && !(readJSON(path.join(wd, 'tiercheck.json'))?.valid === false && createOnce(path.join(wd, 'spawns', 'tiercheck.retry.lock'), now())))
      block('Die unabhängige Komplexitätsbewertung wurde bereits durchgeführt.');
    return;
  }
  if (!run.level) block('Komplexität/Stufe nicht gesetzt (qg-tiercheck, dann tier set).');
  if (t.kind === 'arb') {
    const want = LEVELS[Math.max(LV(run.level), LV(CFG.arbiterMinLevel))];
    if (t.level !== want) block(`Arbiter-Stufe muss ${want} sein.`);
    const m = /DISPUTE:\s*([a-z]+)-([ab])\b/i.exec(ti.prompt || ''); if (!m) block('Arbiter-Auftrag braucht "DISPUTE: <domäne>-<slot>".');
    const p = gatePhase(run.phase); const st = phaseStand(run, p);
    if (!createOnce(path.join(wd, 'spawns', `arb-${t.slot}-${p}-${m[1].toLowerCase()}-${m[2].toLowerCase()}-${t.level}-${short(st)}.lock`), now())) block('Für diesen Befund und Stand gab es bereits einen Schiedsspruch dieses Arbiters.');
    return;
  }
  if (t.level !== run.level) block(`Falsche Stufe: ${ti.subagent_type} – aktuelle Ausführungsstufe ist "${run.level}" (${LEVEL(run.level).label}).`);
  const phaseOk = { req: ['req'], reqcheck: ['req'], design: ['design'], test: ['design'], impl: ['impl', 'code'], rev: ['design', 'code'] }[t.kind];
  if (!phaseOk.includes(run.phase)) block(`${t.kind} ist in Phase "${run.phase}" nicht vorgesehen.${t.kind === 'impl' ? ' Freigabe zur Implementierung (Design-Gate) fehlt.' : ''}`);
  const p = gatePhase(run.phase);
  if (['reqcheck', 'rev', 'impl'].includes(t.kind)) { const b = iterationBlock(run, p); if (b) block(b); }
  if (t.kind === 'reqcheck') {
    const st = phaseStand(run, 'req'); if (!st) block('requirements.md fehlt.');
    if (!createOnce(path.join(wd, 'spawns', `req-reqcheck-a-${run.level}-${short(st)}.lock`), now())) block('Dieser Anforderungsstand wurde auf dieser Stufe bereits gegengeprüft.');
    return;
  }
  if (t.kind === 'rev') {
    if (!CFG.phases[p].domains.includes(t.domain)) block(`Domäne ${t.domain} wird in Phase ${p} nicht geprüft.`);
    if (!workingTreeClean()) block('Ungestagte Änderungen – erst qg stage.');
    const st = phaseStand(run, p); if (!st) block('Prüfstand unvollständig (design.md fehlt?).');
    const checks = readJSON(path.join(wd, `checks-${p}-${short(stagedHash())}.json`));
    if (!checks?.pass) block(`Deterministische Checks (${p}) fehlen oder sind rot – erst qg checks.`);
    const key = path.join(wd, 'spawns', `${p}-${t.domain}-${t.slot}-${run.level}-${short(st)}`);
    if (!createOnce(`${key}.lock`, now())) {
      const prev = jsonList(fsReader(wd), 'verdicts').filter((v) => v.phase === p && v.domain === t.domain && v.slot === t.slot && v.stand === st && v.level === run.level);
      if (prev.length && prev.every((v) => !v.valid) && createOnce(`${key}.retry.lock`, now())) return;
      block(`${p}/${t.domain}/${t.slot.toUpperCase()} wurde für Stand ${short(st)} auf Stufe ${run.level} bereits geprüft (keine Mehrfachprüfung).`);
    }
  }
}

function writeGuard(file, role, admin) {
  if (!file) return;
  const r = rel(path.resolve(ROOT, file));
  if (r.startsWith('..')) { if (isQg(role)) block(`Schreiben außerhalb des Projekts verboten: ${file}`); return; }
  const run = loadRun();
  if (role.kind === 'req') {
    if (run && r === `.quality/runs/${run.id}/requirements.md`) { if (run.reqLock) block('Anforderungen sind freigegeben und gesperrt.'); return; }
    block('Der Anforderungs-Agent schreibt nur requirements.md des Runs.');
  }
  if (role.kind === 'design') {
    if (run && r === `.quality/runs/${run.id}/design.md`) { if (run.phase !== 'design') block('Entwurf ist nach der Freigabe zur Implementierung eingefroren.'); return; }
    block('Der Entwurfs-Agent schreibt nur design.md des Runs.');
  }
  if (admin) return;
  if (['tiercheck', 'reqcheck', 'rev', 'arb'].includes(role.kind)) block(`Rolle ${role.name} ist schreibgeschützt.`);
  if (matchAny(r, CFG.protectedGlobs)) block(`Geschützter Pfad: ${r}`);
  if (role.kind === 'test') {
    if (!matchAny(r, CFG.testGlobs)) block(`Der Test-Agent schreibt nur Testdateien. Abgelehnt: ${r}`);
    if (run?.phase !== 'design') block('Tests sind seit der Freigabe zur Implementierung eingefroren (design reopen nötig).');
  }
  if (role.kind === 'impl') {
    if (!['impl', 'code'].includes(run?.phase)) block('Keine Freigabe zur Implementierung.');
    if (matchAny(r, CFG.testGlobs)) block(`Der Implementierer ändert keine Tests (${r}). TEST-ISSUE melden.`);
    if (matchAny(r, CFG.governanceGlobs)) block(`Governance-Datei ${r} ist für Agenten gesperrt.`);
  }
}

function readGuard(p, role) {
  if (!CHECKER_KINDS.has(role.kind) || !p) return;
  const r = rel(String(p)); const run = loadRun();
  if (r.startsWith('.quality/state') || r === '.quality') block('Prüfer haben keinen Zugriff auf Arbeitsstände anderer Prüfer (Unabhängigkeit).');
  const allowed = run ? [`.quality/runs/${run.id}/requirements.md`, `.quality/runs/${run.id}/design.md`] : [];
  if (r.startsWith('.quality/runs') && !allowed.includes(r)) block('Prüfer lesen nur Anforderungen und Entwurf des aktuellen Runs.');
}

function bashGuard(cmd, role, admin) {
  const flat = stripQuoted(cmd);
  if (/hooksPath/.test(cmd) && !admin) block('Änderung/Umgehung von core.hooksPath ist verboten.');
  if (/qg\.mjs\s+hook\b/.test(cmd)) block('Hook-Einstiegspunkte dürfen nicht manuell aufgerufen werden.');
  if (/qg\.mjs\s+gen-agents\b/.test(cmd) && (isQg(role) || !admin)) block('gen-agents nur durch Menschen im Admin-Modus.');
  const segments = flat.split(/&&|\|\||;|\n/).map((s) => s.trim()).filter(Boolean);
  for (const seg of segments) {
    const toks = splitShell(seg); const gi = toks.indexOf('git');
    if (gi >= 0) {
      const rest = toks.slice(gi + 1); const sub = rest.find((t) => !t.startsWith('-'));
      if (rest.includes('-c') && /core\.|hooks/i.test(rest.join(' '))) block('git -c mit Kern-/Hook-Konfiguration ist verboten.');
      if (sub === 'commit') commitGuard(rest.slice(rest.indexOf('commit') + 1), role);
      if (sub === 'push' && rest.some((t) => t === '-f' || t.startsWith('--force'))) block('Force-Push verboten.');
    }
  }
  if (!isQg(role) || admin) return;
  if (/\.quality\/(state|runs|bin|templates|config)|\.claude\/|\.githooks|\.git\/|\.idea\//.test(cmd)) {
    const m = /^node\s+\.quality\/bin\/qg\.mjs\s+(\S+)/.exec(cmd.trim());
    const okO = role.kind === 'orchestrator' && m && ORCH_QG_CMDS.has(m[1]) && !/[;&|`]|\$\(/.test(flat);
    const okR = role.kind !== 'orchestrator' && m && ['status', 'metrics'].includes(m[1]) && !/[;&|`>]|\$\(/.test(flat);
    if (!okO && !okR) block('Shell-Zugriff auf Gate-Infrastruktur ist für Agenten gesperrt.');
  }
  if (/\b(curl|wget|nc|ncat|ssh|scp|rsync|ftp)\b/.test(flat)) block('Netzwerkwerkzeuge sind gesperrt.');
  if (/--no-verify|\bnpm\s+(config|set)\b/.test(flat)) block('Umgehung von Hooks/Konfiguration ist verboten.');
  // Option B (Beschluss 2026-11-19): Der Orchestrator darf beliebige Shell-, git- und gh-Befehle ausführen.
  // Verblieben sind die Sperren oben: Gate-Infrastruktur, Netzwerkwerkzeuge, --no-verify, Hook-Konfiguration, Commit-Guard.
  if (role.kind === 'orchestrator') return;
  if (CHECKER_KINDS.has(role.kind)) {
    if (/[<>`]|\$\(/.test(flat) || /&&|\|\||;/.test(flat)) block('Prüfer: keine Umleitungen, Verkettungen oder Subshells.');
    const [first, ...filters] = flat.split('|').map((s) => s.trim());
    if (!CFG.reviewerBashAllow.some((re) => new RegExp(re).test(first))) block(`Prüfer: Befehl nicht freigegeben (reviewerBashAllow): ${first}`);
    for (const f of filters) if (!CFG.pipeFilters.includes(splitShell(f)[0])) block(`Pipe-Filter nicht erlaubt: ${f}`);
    return;
  }
  for (const seg of segments) {
    const toks = splitShell(seg); const gi = toks.indexOf('git');
    if (gi >= 0) { const sub = toks.slice(gi + 1).find((t) => !t.startsWith('-')); if (!['status', 'diff', 'log', 'show', 'blame', 'ls-files', 'rev-parse', 'grep'].includes(sub)) block(`git ${sub} ist für ${role.name} gesperrt.`); }
  }
}

function commitGuard(args, role) {
  const valueFlags = new Set(['-m', '--message', '-F', '--file', '-C', '-c', '--reuse-message', '--reedit-message', '--author', '--date', '-t', '--template', '--cleanup', '--trailer']);
  for (let i = 0; i < args.length; i++) {
    const t = args[i];
    if (valueFlags.has(t)) { i++; continue; }
    if (['--no-verify', '--amend', '--all', '--include', '--only', '--allow-empty'].includes(t)) block(`git commit ${t} ist verboten.`);
    if (/^-[a-zA-Z]+$/.test(t)) { const fl = t.slice(1); if (/[naio]/.test(fl.replace(/[mFCc]$/, ''))) block(`git commit ${t}: -n/-a/-i/-o verboten.`); if (/[mFCc]$/.test(fl)) i++; continue; }
    if (!t.startsWith('-')) block(`git commit mit Pfadangaben (${t}) ist verboten.`);
  }
  if (!['human', 'orchestrator'].includes(role.kind)) block('Nur Orchestrator oder Mensch committen.');
  const v = verifyStaged(); if (!v.ok) block(`Commit verweigert: ${v.why}`);
}

hooks['subagent-start'] = () => {
  let input; try { input = JSON.parse(readStdin() || '{}'); } catch { process.exit(0); }
  const role = parseRole(input.agent_type); const run = loadRun();
  if (!isQg(role) || !run) process.exit(0);
  const p = gatePhase(run.phase);
  const rec = { agentId: input.agent_id, agentType: input.agent_type, phase: p, startStand: ['req', 'design', 'code'].includes(p) ? phaseStand(run, p) : null, levelAtStart: run.level, effort: input.effort ?? null };
  writeJSON(path.join(workDir(run.id), 'agents', `${input.agent_id}.start.json`), { ...rec, at: now() });
  appendLog(path.join(workDir(run.id), 'agents.log.jsonl'), { event: 'start', ...rec });
  const mode = { req: 'ANFORDERUNGEN', design: 'DESIGN (vor der Implementierung: Entwurf + Tests prüfen)', code: 'CODE (nach der Implementierung: Code prüfen)' }[p] || run.phase;
  const ctx = `Quality-Gate-Run ${run.id} | Phase/Prüfmodus: ${mode} | Stufe ${run.level || '—'} | Anforderungen: .quality/runs/${run.id}/requirements.md | Entwurf: .quality/runs/${run.id}/design.md | Standards: .quality/standards/STANDARDS.md`;
  process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: 'SubagentStart', additionalContext: ctx } })); process.exit(0);
};

function recordResult(input, text, source) {
  const role = parseRole(input.agent_type); const run = loadRun();
  if (!run || !CHECKER_KINDS.has(role.kind)) return { done: true };
  const wd = workDir(run.id);
  const start = readJSON(path.join(wd, 'agents', `${input.agent_id}.start.json`), {});
  const base = { agentId: input.agent_id, agentType: input.agent_type, recordedAt: now(), source, transcriptModels: modelsFromTranscript(input.agent_transcript_path), effortObserved: input.effort ?? start.effort ?? null };
  const tag = { rev: 'QG-VERDICT', reqcheck: 'QG-VERDICT', arb: 'QG-RULING', tiercheck: 'QG-TIER' }[role.kind];
  const data = extractBlock(text, tag);
  const retry = () => (!input.stop_hook_active ? { done: false, retry: `Kein gültiger ${tag}-Block. Gib als letzte Ausgabe exakt <<<${tag} {JSON} ${tag}>>> aus (siehe Anweisung).` } : null);

  if (role.kind === 'tiercheck') {
    const f = path.join(wd, 'tiercheck.json'); if (readJSON(f)?.valid) return { done: true };
    const okT = data && !data.__parseError && CFG.complexityTiers.includes(String(data.tier).toLowerCase());
    if (!okT) { const r = retry(); if (r) return r; writeJSON(f, { ...base, valid: false }); return { done: true }; }
    const expected = CFG.tierCheck.model; const bad = base.transcriptModels.filter((m) => !modelMatches(m, expected));
    const valid = !bad.length;
    writeJSON(f, { ...base, valid, tier: String(data.tier).toLowerCase(), reasons: data.reasons || [], invalidReason: valid ? null : `falsches Modell ${bad}` });
    if (valid) { run.tierCheck = { tier: String(data.tier).toLowerCase(), reasons: data.reasons || [], at: now(), agentId: input.agent_id }; saveRun(run); }
    return { done: true };
  }
  const p = start.phase || gatePhase(run.phase);
  const stopStand = phaseStand(run, p);
  if (role.kind === 'arb') {
    const out = path.join(wd, 'rulings', `${p}-arb-${role.slot}-${short(stopStand)}-${input.agent_id}.json`); if (fs.existsSync(out)) return { done: true };
    if (!data || data.__parseError) { const r = retry(); if (r) return r; writeJSON(out, { ...base, phase: p, stand: stopStand, arbSlot: role.slot, valid: false, items: [] }); return { done: true }; }
    const items = (Array.isArray(data.items) ? data.items : []).map((it) => ({ ...it, slot: String(it.slot || '').toLowerCase(), decision: String(it.decision || '').toUpperCase(), reason: it.reason || '' }))
      .filter((it) => it.domain && it.slot && it.finding && ['FALSE_POSITIVE', 'CONFIRMED'].includes(it.decision));
    const valid = start.startStand === stopStand && items.every((it) => it.reason.length >= 20);
    writeJSON(out, { ...base, phase: p, stand: stopStand, arbSlot: role.slot, level: role.level, valid, invalidReason: valid ? null : 'Stand geändert oder Begründung fehlt', items });
    return { done: true };
  }
  const domain = role.kind === 'reqcheck' ? 'req' : role.domain; const slot = role.kind === 'reqcheck' ? 'a' : role.slot;
  const out = path.join(wd, 'verdicts', `${p}-${domain}-${slot}-${short(stopStand)}-${input.agent_id}.json`); if (fs.existsSync(out)) return { done: true };
  const head = { ...base, phase: p, domain, slot, level: role.level, stand: stopStand, startStand: start.startStand || null };
  if (!data || data.__parseError) { const r = retry(); if (r) return r; writeJSON(out, { ...head, valid: false, invalidReason: 'kein gültiger Block', result: 'FAIL', findings: [] }); return { done: true }; }
  const n = normalizeVerdict(data, domain, run);
  if (n.errors.length && !input.stop_hook_active) return { done: false, retry: `Verdict-Block fehlerhaft: ${n.errors.join('; ')}. Vollständig korrigiert erneut ausgeben.` };
  let inv = null;
  if (n.errors.length) inv = `Formfehler: ${n.errors.join('; ')}`;
  else if (head.startStand !== stopStand) inv = 'Prüfstand während der Prüfung verändert';
  else if (role.level !== run.level) inv = `Stufe geändert (${role.level} → ${run.level})`;
  else if (p !== gatePhase(run.phase)) inv = 'Phase während der Prüfung gewechselt';
  writeJSON(out, { ...head, valid: !inv, invalidReason: inv, result: inv ? 'FAIL' : n.computed, notes: n.notes, findings: n.findings, summary: data.summary || '', raw: data });
  appendLog(path.join(wd, 'agents.log.jsonl'), { event: 'verdict', agentId: input.agent_id, agentType: input.agent_type, phase: p, result: inv ? 'INVALID' : n.computed });
  return { done: true };
}

hooks['subagent-stop'] = () => {
  let input; try { input = JSON.parse(readStdin() || '{}'); } catch { process.exit(0); }
  const run = loadRun(); const role = parseRole(input.agent_type); if (!run || !isQg(role)) process.exit(0);
  appendLog(path.join(workDir(run.id), 'agents.log.jsonl'), { event: 'stop', agentId: input.agent_id, agentType: input.agent_type, transcriptModels: modelsFromTranscript(input.agent_transcript_path), effort: input.effort ?? null });
  const r = recordResult(input, input.last_assistant_message || '', 'SubagentStop');
  if (!r.done) { process.stderr.write(r.retry + '\n'); process.exit(2); }
  process.exit(0);
};

hooks['post-tool'] = () => {
  let input; try { input = JSON.parse(readStdin() || '{}'); } catch { process.exit(0); }
  const run = loadRun(); if (!run) process.exit(0);
  if (input.tool_name === 'Agent' || input.tool_name === 'Task') {
    const tr = input.tool_response || {};
    for (const m of [tr.resolvedModel, ...(Array.isArray(tr.modelsUsed) ? tr.modelsUsed : [])].filter(Boolean))
      appendLog(path.join(workDir(run.id), 'agents.log.jsonl'), { event: 'model', agentId: tr.agentId || tr.agent_id, subagentType: input.tool_input?.subagent_type, resolvedModel: m, status: tr.status });
  }
  if (input.tool_name === 'SubagentHandback') recordResult(input, String(input.tool_input?.message || ''), 'SubagentHandback');
  process.exit(0);
};

hooks['git-pre-commit'] = () => {
  if (CFG.gitHook?.mode === 'off') process.exit(0);
  const changed = git(['diff', '--cached', '--name-only']).stdout.split('\n').filter(Boolean).filter((f) => !f.startsWith('.quality/runs/') && !f.startsWith('.quality/state/'));
  if (!changed.length) process.exit(0);
  const v = verifyStaged(); if (v.ok) process.exit(0);
  const msg = `\n✖ Quality-Gate: ${v.why}\n  Status: node .quality/bin/qg.mjs status\n`;
  if (CFG.gitHook?.mode === 'warn') { process.stderr.write(msg + '  (Modus "warn")\n'); process.exit(0); }
  process.stderr.write(msg); process.exit(1);
};
hooks['commit-msg'] = () => {
  const file = process.argv[4]; const id = currentRunId(); const gate = id && readJSON(path.join(runDir(id), 'gate.json'));
  if (!file || !gate?.pass) process.exit(0);
  let msg = fs.readFileSync(file, 'utf8');
  if (!msg.includes(`QG-Run: ${id}`)) msg = msg.replace(/\s*$/, '') + `\n\nQG-Run: ${id}\nQG-Hash: ${gate.stand}\nQG-Level: ${gate.level}\n`;
  fs.writeFileSync(file, msg); process.exit(0);
};
hooks['git-post-commit'] = () => {
  const id = currentRunId(); if (!id) process.exit(0);
  const gate = readJSON(path.join(runDir(id), 'gate.json'));
  if (!gate || !git(['diff-tree', '--no-commit-id', '--name-only', '-r', 'HEAD']).stdout.includes(`.quality/runs/${id}/gate.json`)) process.exit(0);
  const sha = git(['rev-parse', 'HEAD']).stdout.trim();
  appendLog(path.join(STATE_DIR, 'history.jsonl'), { runId: id, commit: sha, stand: gate.stand });
  fs.rmSync(statePath(), { force: true });
  process.stdout.write(`Quality-Gate-Run ${id} abgeschlossen mit Commit ${short(sha)}.\n`); process.exit(0);
};
commands.hook = (args) => { const h = hooks[args[0]]; if (!h) fail(`Unbekannter Hook: ${args[0]}`); h(); };

// ------------------------------------------------------------------ Generator
commands['gen-agents'] = () => {
  const T = (n) => fs.readFileSync(path.join(QDIR, 'templates', n), 'utf8');
  const outDir = path.join(ROOT, '.claude', 'agents', 'qg');
  fs.rmSync(outDir, { recursive: true, force: true }); fs.mkdirSync(outDir, { recursive: true });
  const fill = (s, v) => s.replace(/\{\{(\w+)\}\}/g, (_, k) => (v[k] ?? `{{${k}}}`));
  const header = '<!-- GENERIERT von .quality/bin/qg.mjs gen-agents – nicht von Hand ändern. Quelle: .quality/templates/ + .quality/config.json -->\n';
  const fm = (o) => '---\n' + Object.entries(o).filter(([, v]) => v !== undefined).map(([k, v]) => `${k}: ${typeof v === 'string' ? JSON.stringify(v) : v}`).join('\n') + '\n---\n' + header;
  const names = [];
  const emit = (name, front, body) => { fs.writeFileSync(path.join(outDir, `${name}.md`), fm({ name, ...front }) + '\n' + body.trim() + '\n'); names.push(name); };
  const RO = 'Write, Edit, MultiEdit, NotebookEdit, Agent, WebFetch, WebSearch';
  const persp = { a: T('perspective-a.md'), b: T('perspective-b.md') };
  const allDomains = [...new Set([...CFG.phases.design.domains, ...CFG.phases.code.domains])];
  for (const lv of CFG.levels) {
    const v = { LEVEL: lv.id, LABEL: lv.label };
    const f = { model: lv.model, effort: lv.effort };
    emit(`qg-req-${lv.id}`, { description: `Anforderungsanalyse (Stufe ${lv.id}). Nur vom qg-orchestrator.`, ...f, tools: 'Read, Grep, Glob, Write', disallowedTools: 'Agent, WebFetch, WebSearch', color: 'blue', maxTurns: 60 }, fill(T('requirements.md'), v));
    emit(`qg-reqcheck-${lv.id}`, { description: `Unabhängige Gegenprüfung der Anforderungen (Stufe ${lv.id}). Nur vom qg-orchestrator.`, ...f, tools: 'Read, Grep, Glob, Bash', disallowedTools: RO, color: 'yellow', maxTurns: 50 }, fill(T('reqcheck.md'), v));
    emit(`qg-design-${lv.id}`, { description: `Lösungsentwurf vor der Implementierung (Stufe ${lv.id}). Nur vom qg-orchestrator.`, ...f, tools: 'Read, Grep, Glob, Write', disallowedTools: 'Agent, WebFetch, WebSearch', color: 'blue', maxTurns: 80 }, fill(T('design.md'), v));
    emit(`qg-test-${lv.id}`, { description: `Test-Autor, test-first (Stufe ${lv.id}). Nur vom qg-orchestrator.`, ...f, tools: 'Read, Grep, Glob, Write, Edit, Bash', disallowedTools: 'Agent, WebFetch, WebSearch', color: 'cyan', maxTurns: 120 }, fill(T('test-author.md'), v));
    emit(`qg-impl-${lv.id}`, { description: `Implementierer nach Freigabe (Stufe ${lv.id}). Nur vom qg-orchestrator.`, ...f, tools: 'Read, Grep, Glob, Write, Edit, Bash, mcp__ide__getDiagnostics', disallowedTools: 'Agent, WebFetch, WebSearch', color: 'green', maxTurns: 200 }, fill(T('implementer.md'), v));
    for (const d of allDomains) for (const s of ['a', 'b']) {
      emit(`qg-rev-${d}-${s}-${lv.id}`, { description: `Unabhängige Prüfung ${d}, Prüfer ${s.toUpperCase()} (Stufe ${lv.id}). Nur vom qg-orchestrator.`, ...f, tools: 'Read, Grep, Glob, Bash, mcp__ide__getDiagnostics', disallowedTools: RO, color: s === 'a' ? 'yellow' : 'orange', maxTurns: 80 },
        fill(T('reviewer.md'), { ...v, DOMAIN: d, SLOT: s.toUpperCase(), PERSPECTIVE: persp[s], CHECKLIST: T(`domain-${d}.md`) }));
    }
    if (LV(lv.id) >= LV(CFG.arbiterMinLevel)) for (const s of ['a', 'b'])
      emit(`qg-arb-${s}-${lv.id}`, { description: `Schiedsinstanz ${s.toUpperCase()} für bestrittene Befunde (Stufe ${lv.id}). Nur vom qg-orchestrator mit "DISPUTE: <domäne>-<slot>".`, ...f, tools: 'Read, Grep, Glob, Bash', disallowedTools: RO, color: 'red', maxTurns: 40 }, fill(T('arbiter.md'), { ...v, SLOT: s.toUpperCase() }));
  }
  emit('qg-tiercheck', { description: 'Unabhängige Gegenprüfung der Komplexitätsbewertung. Nur vom qg-orchestrator.', model: CFG.tierCheck.model, effort: CFG.tierCheck.effort, tools: 'Read, Grep, Glob', disallowedTools: RO, color: 'purple', maxTurns: 30 }, fill(T('tiercheck.md'), {}));
  const levelTable = CFG.levels.map((l, i) => `| ${l.id} | ${l.model} | ${l.effort} | ${i < CFG.complexityTiers.length ? 'Komplexität ' + l.id : 'nur Eskalation'} |`).join('\n');
  fs.writeFileSync(path.join(ROOT, '.claude', 'agents', 'qg-orchestrator.md'),
    fm({ name: 'qg-orchestrator', description: 'Orchestrator des Quality-Gates. Als Hauptagent starten mit: claude --agent qg-orchestrator', model: CFG.orchestrator.model, effort: CFG.orchestrator.effort, tools: `Agent(${names.join(', ')}), Read, Grep, Glob, Write, Edit, MultiEdit, Bash, TodoWrite, AskUserQuestion`, color: 'purple' })
    + '\n' + fill(T('orchestrator.md'), { LEVEL_TABLE: levelTable, OPT: String(POL.optionalEscalationAfter), MAND: String(POL.mandatoryEscalationAfter), STOP: String(POL.stopAfter),
      DESIGN_DOMAINS: CFG.phases.design.domains.join(', '), CODE_DOMAINS: CFG.phases.code.domains.join(', '), ARB_MIN: CFG.arbiterMinLevel }).trim() + '\n');
  writeJSON(path.join(QDIR, 'agents.manifest.json'), { generatedAt: now(), configHash: sha256(fs.readFileSync(path.join(QDIR, 'config.json'))), agents: ['qg-orchestrator', ...names] });
  ok(`${names.length + 1} Agentendateien erzeugt.`);
};

// ------------------------------------------------------------------ doctor
commands.doctor = () => {
  const rows = []; const add = (k, w, h = '') => rows.push(`${k ? '✔' : '✖'} ${w}${k || !h ? '' : '  → ' + h}`);
  add(+process.versions.node.split('.')[0] >= 20, `Node ${process.versions.node} (>= 20)`);
  add(git(['--version'], { allowFail: true }).status === 0, 'git verfügbar');
  add(git(['config', '--get', 'core.hooksPath'], { allowFail: true }).stdout.trim() === '.githooks', 'core.hooksPath = .githooks', 'git config core.hooksPath .githooks');
  for (const h of ['pre-commit', 'commit-msg', 'post-commit']) add(fs.existsSync(path.join(ROOT, '.githooks', h)), `.githooks/${h}`);
  const st = readJSON(path.join(ROOT, '.claude', 'settings.json'), {}); add(!!st.hooks?.PreToolUse && !!st.hooks?.SubagentStop, 'settings.json mit QG-Hooks');
  const man = readJSON(path.join(QDIR, 'agents.manifest.json')); add(!!man, 'Agenten generiert', 'QG_ADMIN=1 node .quality/bin/qg.mjs gen-agents');
  if (man) add(man.configHash === sha256(fs.readFileSync(path.join(QDIR, 'config.json'))), 'Agenten passen zur config.json', 'gen-agents erneut');
  const gi = fs.existsSync(path.join(ROOT, '.gitignore')) ? fs.readFileSync(path.join(ROOT, '.gitignore'), 'utf8') : '';
  add(/\.quality\/state/.test(gi), '.quality/state/ in .gitignore');
  add(!process.env.CLAUDE_CODE_SUBAGENT_MODEL_FORCE, 'CLAUDE_CODE_SUBAGENT_MODEL_FORCE nicht gesetzt');
  add(!process.env.CLAUDE_CODE_SUBAGENT_MODEL, 'CLAUDE_CODE_SUBAGENT_MODEL nicht gesetzt');
  for (const c of [...CFG.designChecks, ...CFG.checks].filter((c) => c.cmd)) {
    const parts = c.cmd.split(' '); const bin = parts[0] === 'npx' ? parts[1] : parts[0];
    const found = parts[0] === 'npx' ? fs.existsSync(path.join(ROOT, 'node_modules', '.bin', bin)) || fs.existsSync(path.join(ROOT, 'node_modules', '.bin', bin + '.cmd'))
      : spawnSync(process.platform === 'win32' ? 'where' : 'which', [bin], { encoding: 'utf8' }).status === 0;
    add(found || !c.required, `Werkzeug "${c.id}": ${bin}`, parts[0] === 'npx' ? `npm i -D ${bin}` : `${bin} installieren`);
  }
  process.stdout.write([...new Set(rows)].join('\n') + '\n'); process.exit(rows.some((r) => r.startsWith('✖')) ? 1 : 0);
};

// ------------------------------------------------------------------ main
const [cmd, ...rest] = process.argv.slice(2);
if (!cmd || !commands[cmd]) {
  process.stdout.write(`qg.mjs v2 – Quality-Gate
  init --title "<Auftrag>"                      Run anlegen (Phase tier)
  tier set <low|medium|high> --reason "<…>"     Komplexität (≥ Gegenprüfung, ≥ Mindeststufe)
  req lock --approved-by "<Name>"               Anforderungen freigeben (nach Anforderungs-Gate)
  stage | checks | gate                         Prüfstand, deterministische Checks, Gate der aktuellen Phase
  escalate --reason "<…>"                       Modell+Effort eine Stufe höher (nach ${POL.optionalEscalationAfter} optional, nach ${POL.mandatoryEscalationAfter} Pflicht)
  design reopen --reason "<…>"                  zurück vor die Freigabe zur Implementierung
  finalize | abort --reason "<…>" | status | metrics
  verify-staged | verify-commit <sha> | gen-agents | doctor
`);
  process.exit(cmd ? 1 : 0);
}
commands[cmd](rest);
