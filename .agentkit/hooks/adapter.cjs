#!/usr/bin/env node
// Portable hook adapter for Claude Code and Codex. Usage: adapter <host> <mode>
//   pre      PreToolUse: block destructive commands and secret access (exit 2), advise on broad searches
//   post     PostToolUse: one-time advice when an edited source file grows large
//   session  SessionStart: surface the active plan and its next open phase (plus kit instructions as a plugin);
//            on a Claude startup, show a one-line hint suggesting prismantis until it is installed or declined
//   flag     adapter claude flag prismantis installed|remind-off|remind-on: update the user-level hint state
// Malformed or unknown payloads never interrupt work. Optional settings: .agentkit/config.json
//   {"guard": false} disables blocking; {"guard": {"allow": ["force-push"]}} allows single rules;
//   {"maxLines": 300} changes the large-file threshold.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const host = process.argv[2];
const mode = {search: 'pre', modularization: 'post'}[process.argv[3]] || process.argv[3];
// Installed copy: <project>/.agentkit/hooks/adapter.cjs. Plugin copy: ${CLAUDE_PLUGIN_ROOT}/hooks/adapter.cjs,
// where the project comes from CLAUDE_PROJECT_DIR and instructions are injected at session start.
const ownRoot = path.resolve(__dirname, '..');
const real = p => { try { return fs.realpathSync(p); } catch { return path.resolve(p); } };
const pluginRoot = process.env.CLAUDE_PLUGIN_ROOT && real(process.env.CLAUDE_PLUGIN_ROOT) === real(ownRoot) ? ownRoot : null;
const projectRoot = pluginRoot ? path.resolve(process.env.CLAUDE_PROJECT_DIR || process.cwd()) : path.dirname(ownRoot);
function config() {
  try { return JSON.parse(fs.readFileSync(path.join(projectRoot, '.agentkit', 'config.json'), 'utf8')) || {}; } catch { return {}; }
}
function context(event, message, hint) {
  const out = message ? {hookSpecificOutput: {hookEventName: event, additionalContext: message}} : {};
  if (hint) out.systemMessage = hint;
  console.log(JSON.stringify(out));
}
// User-level state, shared by every project: {"prismantis": {"installed": bool, "remind": bool}}.
const stateFile = () => path.join(process.env.AGENTKIT_STATE_DIR || path.join(os.homedir(), '.agentkit'), 'state.json');
function readState() {
  try { const s = JSON.parse(fs.readFileSync(stateFile(), 'utf8')); return s && typeof s === 'object' && !Array.isArray(s) ? s : {}; } catch { return {}; }
}
function prismantisState(state) {
  const p = state.prismantis && typeof state.prismantis === 'object' ? state.prismantis : {};
  return {installed: p.installed === true, remind: p.remind !== false};
}
function writePrismantis(change) {
  const state = readState(), file = stateFile();
  state.prismantis = {...prismantisState(state), ...change};
  fs.mkdirSync(path.dirname(file), {recursive: true});
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(state, null, 2) + '\n');
  fs.renameSync(tmp, file);
  return state.prismantis;
}
function prismantisInstalled() {
  const dir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
  try {
    const data = JSON.parse(fs.readFileSync(path.join(dir, 'plugins', 'installed_plugins.json'), 'utf8'));
    return Object.keys(data.plugins || data).some(k => k.startsWith('prismantis@'));
  } catch { return false; }
}
// Only when the user starts Claude, not on resume, clear or compact.
function prismantisHint(payload) {
  if (host !== 'claude' || payload.source !== 'startup') return null;
  try {
    const {installed, remind} = prismantisState(readState());
    if (installed) return null;
    if (prismantisInstalled()) { writePrismantis({installed: true}); return null; }
    if (!remind) return null;
  } catch { return null; }
  const command = pluginRoot ? '/agentkit:kit-prismantis' : '/kit-prismantis';
  return `Tip: prismantis renders Claude's replies in color (tables, diagrams, themes). Run ${command} to install it or turn off this tip.`;
}
function flag(args) {
  const change = {installed: {installed: true}, 'remind-off': {remind: false}, 'remind-on': {remind: true}}[args[1]];
  if (args[0] !== 'prismantis' || !change) {
    process.stderr.write('Usage: adapter claude flag prismantis installed|remind-off|remind-on\n');
    process.exit(1);
  }
  console.log(JSON.stringify({prismantis: writePrismantis(change)}));
}
function block(rule, reason) {
  process.stderr.write(`AgentKit guard (${rule}): ${reason} If the user explicitly asked for this, ask them to run it themselves or allow "${rule}" in .agentkit/config.json.\n`);
  process.exit(2);
}
const secretFile = name => {
  const base = path.basename(String(name));
  if (/^\.env(\..+)?$/.test(base)) return !/\.(example|sample|template|dist)$/.test(base);
  return /^(id_rsa|id_ed25519|id_ecdsa)$/.test(base) || /\.(pem|p12|pfx|key)$/.test(base);
};
const commandRules = [
  ['rm-rf', /\brm\s+(?:-\w+\s+)*-(?:\w*r\w*f|\w*f\w*r)\w*\s+(?:-\w+\s+)*(?:--\s+)?(?:\/|\/\*|~\/?|\$HOME\/?|\.\.?\/?|\*)(?=\s|$|;|&|\|)/, 'Recursive force delete of a root, home, parent or whole project directory.'],
  ['force-push', /\bgit\s+push\b(?=[^;&|]*\s(?:--force|-f)(?:\s|$))(?![^;&|]*--force-with-lease)/, 'Force push rewrites remote history; prefer --force-with-lease after confirming with the user.'],
  ['reset-hard', /\bgit\s+reset\b[^;&|]*--hard\b/, 'git reset --hard discards uncommitted work.'],
  ['git-clean', /\bgit\s+clean\b[^;&|]*\s-\w*f/, 'git clean -f permanently deletes untracked files.'],
  ['secrets', /\b(?:cat|less|more|head|tail|bat|strings|xxd|base64)\b[^;&|]*?[\s'"/](?:\.env(?:\.(?!example\b|sample\b|template\b|dist\b)[\w.-]+)?|id_rsa|id_ed25519|[\w.-]+\.pem)(?=$|[\s'";&|])/, 'Reading secret files exposes credentials to the model and logs.'],
];
function pre(input, settings) {
  const guard = settings.guard === false ? null : new Set(settings.guard?.allow || []);
  const command = typeof (input.command ?? input.cmd) === 'string' ? (input.command ?? input.cmd) : '';
  const files = [input.file_path, input.path, input.notebook_path].filter(v => typeof v === 'string');
  const patch = typeof input.patch === 'string' ? input.patch : command;
  for (const m of patch.matchAll(/^\*\*\* (?:Add|Update|Delete) File: (.+)$/gm)) files.push(m[1].trim());
  if (guard) {
    if (!guard.has('secrets')) for (const f of files) if (secretFile(f)) block('secrets', `Access to ${path.basename(f)} is blocked to protect credentials.`);
    for (const [rule, pattern, reason] of commandRules) if (!guard.has(rule) && pattern.test(command)) block(rule, reason);
  }
  // Advisory only: a search that explicitly includes dependency or VCS directories.
  if (/^\s*(rg|grep|find)\s/.test(command) && /(?:^|[\s/])(?:node_modules|\.git|__pycache__)(?:[/\s]|$)/.test(command))
    context('PreToolUse', 'This search includes generated or dependency directories. Prefer a scoped source search unless dependency investigation is intended.');
}
const sourceExt = /\.(?:[cm]?[jt]sx?|py|rb|go|rs|java|kt|kts|swift|php|cs|cpp|cc|c|h|hpp|vue|svelte|dart|scala|ex|exs)$/i;
function post(input, payload, settings) {
  const names = [];
  if (typeof input.file_path === 'string') names.push(input.file_path);
  const patch = input.patch ?? input.command;
  if (typeof patch === 'string') for (const m of patch.matchAll(/^\*\*\* (?:Add|Update) File: (.+)$/gm)) names.push(m[1].trim());
  const cwd = path.resolve(payload.cwd || process.cwd()), limit = Number(settings.maxLines) || 200;
  // Advise once per file per session so repeated edits stay quiet.
  const session = String(payload.session_id || '').replace(/[^\w-]/g, '');
  const seenFile = session && path.join(os.tmpdir(), `agentkit-hook-${session}.json`);
  let seen = [];
  if (seenFile) try { seen = JSON.parse(fs.readFileSync(seenFile, 'utf8')); } catch { /* first advice in this session */ }
  for (const name of new Set(names)) {
    if (!sourceExt.test(name)) continue;
    const file = path.resolve(cwd, name), rel = path.relative(cwd, file);
    if (rel.startsWith('..') || path.isAbsolute(rel) || seen.includes(rel)) continue;
    try {
      const realRel = path.relative(fs.realpathSync(cwd), fs.realpathSync(file));
      if (realRel.startsWith('..') || path.isAbsolute(realRel)) continue;
      const stat = fs.statSync(file);
      if (!stat.isFile() || stat.size > 1024 * 1024) continue;
      const text = fs.readFileSync(file, 'utf8'); if (text.includes('\0')) continue;
      const lines = text.split('\n').length;
      if (lines > limit) {
        context('PostToolUse', `${rel} has ${lines} lines. Consider extracting cohesive modules if that improves this task.`);
        seen.push(rel);
        if (seenFile) try { fs.writeFileSync(seenFile, JSON.stringify(seen)); } catch { /* advice may repeat */ }
      }
    } catch { /* A deleted or unavailable file needs no advice. */ }
  }
}
function session(payload) {
  const parts = [];
  // A project installed with the CLI already carries these instructions in CLAUDE.md.
  if (pluginRoot && !fs.existsSync(path.join(projectRoot, '.agentkit', 'manifest.json'))) {
    try { parts.push(fs.readFileSync(path.join(pluginRoot, 'instructions.md'), 'utf8').replaceAll('{{PLUGIN_ROOT}}', pluginRoot.split(path.sep).join('/')).trim()); } catch { /* instructions are optional */ }
  }
  const plan = activePlan();
  if (plan) parts.push(plan);
  const hint = prismantisHint(payload);
  if (parts.length || hint) context('SessionStart', parts.join('\n\n'), hint);
}
function activePlan() {
  const plans = path.join(projectRoot, 'plans');
  let dirs = [];
  try { dirs = fs.readdirSync(plans, {withFileTypes: true}).filter(d => d.isDirectory()).map(d => d.name).sort().reverse(); } catch { return null; }
  for (const dir of dirs) {
    const base = path.join(plans, dir);
    if (!fs.existsSync(path.join(base, 'plan.md'))) continue;
    const phases = fs.readdirSync(base).filter(f => /^phase-.*\.md$/.test(f)).sort();
    const open = phases.map(f => [f, (fs.readFileSync(path.join(base, f), 'utf8').match(/^\s*[-*] \[ \]/gm) || []).length]).filter(([, n]) => n);
    const overviewOpen = (fs.readFileSync(path.join(base, 'plan.md'), 'utf8').match(/^\s*[-*] \[ \]/gm) || []).length;
    if (!open.length && !overviewOpen) continue;
    const next = open.length ? ` Next phase: plans/${dir}/${open[0][0]} (${open[0][1]} open todos).` : '';
    return `Active AgentKit plan: plans/${dir}/plan.md.${next} Read it before continuing plan work; ignore it for unrelated requests.`;
  }
  return null;
}
if (mode === 'flag') flag(process.argv.slice(4));
else try {
  const raw = fs.readFileSync(0, 'utf8');
  const payload = raw.trim() ? JSON.parse(raw) : {};
  let input = payload.tool_input;
  if (typeof input === 'string') { try { input = JSON.parse(input); } catch { input = {command: input}; } }
  if (mode === 'session') session(payload);
  else if (input && typeof input === 'object' && mode === 'pre') pre(input, config());
  else if (input && typeof input === 'object' && mode === 'post') post(input, payload, config());
} catch { /* Malformed/unknown payloads must not interrupt work. */ }
