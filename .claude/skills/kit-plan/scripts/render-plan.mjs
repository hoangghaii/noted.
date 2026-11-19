#!/usr/bin/env node
// Render a plan directory (plan.md + linked phase files) into a single plan.html view, or any other
// Markdown file (for example brainstorm.md) into <name>.html beside it, without phases or progress.
// The Markdown stays the source of truth; the HTML is a derived, git-ignored view.
// Usage: node render-plan.mjs <plan-dir|file.md> [--open]
import fs from 'node:fs';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

export const STATUSES = ['pending', 'implementing', 'testing', 'fixing', 'reviewing', 'awaiting-review', 'done', 'blocked'];
// Pinned CDN builds with Subresource Integrity; bump version and hash together.
export const CDN = [
  {src: 'https://cdn.jsdelivr.net/npm/marked@15.0.12/marked.min.js', integrity: 'sha384-948ahk4ZmxYVYOc+rxN1H2gM1EJ2Duhp7uHtZ4WSLkV4Vtx5MUqnV+l7u9B+jFv+'},
  {src: 'https://cdn.jsdelivr.net/npm/dompurify@3.2.6/dist/purify.min.js', integrity: 'sha384-JEyTNhjM6R1ElGoJns4U2Ln4ofPcqzSsynQkmEc/KGy6336qAZl70tDLufbkla+3'},
  {src: 'https://cdn.jsdelivr.net/npm/mermaid@11.6.0/dist/mermaid.min.js', integrity: 'sha384-zkWMJO4sgpPUzyuOgDx8HB/K55glbAwajEpk1Go2NWRuPkPA/wIhoEJTuSkmOYrV'},
];

const stripFences = md => md.replace(/^(```|~~~)[^\n]*\n[\s\S]*?^\1[^\n]*$/gm, '');
const cells = line => line.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map(c => c.trim());
const plain = text => text.replace(/\*\*|__|[*`]/g, '').trim();

// Find the first Markdown table whose header has a "Phase" column and return its rows.
// Each row: {number, name, file, status, executor}. `hasStatus` is false when the table has no Status column.
export function parsePhaseTable(md) {
  const lines = stripFences(md).split('\n');
  for (let i = 0; i < lines.length - 1; i++) {
    if (!lines[i].trim().startsWith('|') || !/^\s*\|?\s*:?-{3,}/.test(lines[i + 1])) continue;
    const header = cells(lines[i]).map(h => plain(h).toLowerCase());
    const col = name => header.indexOf(name);
    if (col('phase') < 0) continue;
    const rows = [];
    for (let j = i + 2; j < lines.length && lines[j].trim().startsWith('|'); j++) {
      const row = cells(lines[j]), phase = row[col('phase')] || '';
      const link = phase.match(/\[([^\]]+)\]\(([^)\s]+)\)/);
      rows.push({
        number: col('#') >= 0 ? plain(row[col('#')] || '') : String(rows.length + 1),
        name: plain(link ? link[1] : phase),
        file: link ? decodeURIComponent(link[2].split('#')[0]) : null,
        status: col('status') >= 0 ? plain(row[col('status')] || '').toLowerCase() || 'pending' : null,
        executor: col('executor') >= 0 ? plain(row[col('executor')] || '') || null : null,
      });
    }
    return {hasStatus: col('status') >= 0, rows};
  }
  return {hasStatus: false, rows: []};
}

// Count Markdown task-list items outside fenced code blocks.
export function countTodos(md) {
  const items = stripFences(md).match(/^\s*[-*+] \[[ xX]\]/gm) || [];
  const done = items.filter(item => /\[[xX]\]$/.test(item)).length;
  return {done, total: items.length};
}

const statusClass = status => STATUSES.includes(status) ? status : 'other';
const mermaidLabel = text => text.replace(/"/g, '#quot;').replace(/[<>]/g, '');

// "1. Name" would make Mermaid parse the label as a Markdown list, so number with a middle dot.
// A left-to-right chain of phases in table order, coloured by status.
export function buildMermaid(phases) {
  if (!phases.length) return '';
  const lines = ['flowchart LR'];
  phases.forEach((p, i) => {
    const node = `p${i + 1}["${mermaidLabel(`${p.number} · ${p.name}`)}${p.status ? `<br/><small>${mermaidLabel(p.status)}</small>` : ''}"]:::${statusClass(p.status)}`;
    lines.push(i === 0 ? `  ${node}` : `  p${i} --> ${node}`);
  });
  const colors = {pending: '#94a3b8', implementing: '#3b82f6', testing: '#8b5cf6', fixing: '#f59e0b', reviewing: '#ec4899', 'awaiting-review': '#06b6d4', done: '#22c55e', blocked: '#ef4444', other: '#94a3b8'};
  for (const [name, color] of Object.entries(colors)) lines.push(`  classDef ${name} fill:${color}33,stroke:${color},stroke-width:2px`);
  return lines.join('\n');
}

// Read plan.md and its linked phase files (or a single Markdown file) into the data the page renders.
export function loadPlan(input) {
  const planFile = fs.existsSync(input) && fs.statSync(input).isDirectory() ? path.join(input, 'plan.md') : input;
  if (!fs.existsSync(planFile)) throw new Error(`Markdown file not found: ${planFile}`);
  if (!planFile.endsWith('.md')) throw new Error(`Not a Markdown file: ${planFile}`);
  const dir = path.dirname(planFile), md = fs.readFileSync(planFile, 'utf8');
  const single = path.basename(planFile) !== 'plan.md';
  const table = single ? {hasStatus: false, rows: []} : parsePhaseTable(md);
  const phases = table.rows.map(row => {
    const full = row.file && !/^[a-z]+:/i.test(row.file) ? path.join(dir, row.file) : null;
    const exists = Boolean(full && fs.existsSync(full) && fs.statSync(full).isFile());
    const body = exists ? fs.readFileSync(full, 'utf8') : '';
    return {...row, missing: Boolean(row.file) && !exists, md: body, todos: countTodos(body)};
  });
  const heading = md.match(/^#\s+(.+)$/m);
  const title = (heading && plain(heading[1])) || path.basename(dir);
  const done = phases.filter(p => p.status === 'done').length;
  const progress = table.hasStatus && phases.length ? {done, total: phases.length} : null;
  // The page header shows the title, so drop that heading from the rendered overview.
  const overview = heading ? md.slice(0, heading.index) + md.slice(heading.index + heading[0].length).replace(/^\n+/, '') : md;
  const output = path.basename(planFile).replace(/\.md$/, '.html');
  return {dir, output, title, md: overview, phases, progress, mermaid: buildMermaid(phases)};
}

const escapeHtml = text => String(text).replace(/[&<>"']/g, c => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c]));
// JSON inside <script> must not contain "<" so "</script>" or "<!--" cannot end the element early.
const scriptJson = value => JSON.stringify(value).replace(/</g, '\\u003c');

export function renderHtml(plan, now = new Date()) {
  const data = {title: plan.title, md: plan.md, phases: plan.phases, progress: plan.progress, mermaid: plan.mermaid, rendered: now.toISOString()};
  const scripts = CDN.map(s => `<script src="${s.src}" integrity="${s.integrity}" crossorigin="anonymous"></script>`).join('\n');
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(plan.title)}</title>
<style>
:root{--bg:#f8fafc;--panel:#fff;--text:#0f172a;--muted:#64748b;--border:#e2e8f0;--accent:#2563eb;--code:#f1f5f9;
--pending:#64748b;--implementing:#2563eb;--testing:#7c3aed;--fixing:#d97706;--reviewing:#db2777;--awaiting-review:#0891b2;--done:#16a34a;--blocked:#dc2626;--other:#64748b}
@media (prefers-color-scheme:dark){:root{--bg:#0b1120;--panel:#111827;--text:#e5e7eb;--muted:#94a3b8;--border:#1f2937;--accent:#60a5fa;--code:#1e293b;
--pending:#94a3b8;--implementing:#60a5fa;--testing:#a78bfa;--fixing:#fbbf24;--reviewing:#f472b6;--awaiting-review:#22d3ee;--done:#4ade80;--blocked:#f87171;--other:#94a3b8}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:15px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:960px;margin:0 auto;padding:24px 16px 64px}
header h1{font-size:1.6rem;line-height:1.3;margin:0 0 4px}
.meta{color:var(--muted);font-size:.85rem}
section{background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:16px 20px;margin-top:16px;overflow-x:auto}
.bar{height:10px;border-radius:999px;background:var(--border);overflow:hidden;margin:8px 0}
.bar>span{display:block;height:100%;background:var(--done)}
.warn{border-color:var(--fixing);color:var(--text)}
.badge{display:inline-block;padding:1px 10px;border-radius:999px;font-size:.78rem;font-weight:600;border:1px solid currentColor;white-space:nowrap}
${[...STATUSES, 'other'].map(s => `.s-${s}{color:var(--${s})}`).join('')}
details{border:1px solid var(--border);border-radius:10px;margin:10px 0;background:var(--panel)}
summary{cursor:pointer;padding:10px 14px;display:flex;gap:10px;align-items:center;flex-wrap:wrap}
summary .name{font-weight:600;flex:1;min-width:12rem}
summary .todos{color:var(--muted);font-size:.85rem}
details>.body{padding:0 18px 12px;border-top:1px solid var(--border);overflow-x:auto}
table{border-collapse:collapse;width:100%;margin:12px 0;font-size:.92rem}
th,td{border:1px solid var(--border);padding:6px 10px;text-align:left;vertical-align:top}
th{background:var(--code)}
code{background:var(--code);padding:1px 5px;border-radius:4px;font-size:.88em;overflow-wrap:anywhere}
pre{background:var(--code);padding:12px;border-radius:8px;overflow-x:auto}
pre code{padding:0;background:none}
a{color:var(--accent)}
.mermaid{text-align:center;overflow-x:auto}
li:has(>input[type=checkbox]){list-style:none;margin-left:-1.2em}
</style>
</head>
<body>
<main>
<header><h1 id="title">${escapeHtml(plan.title)}</h1><div class="meta" id="meta"></div></header>
<section id="progress" hidden></section>
<section id="diagram" hidden><pre class="mermaid" id="phase-graph"></pre></section>
<section id="overview"></section>
<div id="phases"></div>
</main>
<script type="application/json" id="plan-data">${scriptJson(data)}</script>
${scripts}
<script>
(() => {
  const data = JSON.parse(document.getElementById('plan-data').textContent);
  const $ = id => document.getElementById(id);
  const esc = t => String(t).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const known = ${JSON.stringify(STATUSES)};
  const cls = s => 's-' + (known.includes(s) ? s : 'other');
  const anchor = file => 'phase-' + String(file).replace(/[^a-z0-9-]/gi, '-');
  $('meta').textContent = 'Rendered ' + new Date(data.rendered).toLocaleString() + ' from Markdown; edit the .md files, not this page.';
  const ready = typeof marked !== 'undefined' && typeof DOMPurify !== 'undefined';
  const md = text => {
    if (!ready) return '<pre>' + esc(text) + '</pre>';
    const html = DOMPurify.sanitize(marked.parse(text, {gfm: true}));
    const box = document.createElement('div'); box.innerHTML = html;
    box.querySelectorAll('code.language-mermaid').forEach(code => {
      const div = document.createElement('pre'); div.className = 'mermaid'; div.textContent = code.textContent;
      code.parentElement.replaceWith(div);
    });
    box.querySelectorAll('a[href]').forEach(a => {
      const href = a.getAttribute('href');
      const hit = data.phases.find(p => p.file && href.split('#')[0] === p.file);
      if (hit && !hit.missing) a.setAttribute('href', '#' + anchor(hit.file));
    });
    return box.innerHTML;
  };
  if (!ready) {
    const note = document.createElement('section'); note.className = 'warn';
    note.textContent = 'Could not load the Markdown renderer from the CDN. Showing raw Markdown; check your connection and refresh.';
    $('overview').before(note);
  }
  if (data.progress) {
    const pct = Math.round(data.progress.done / data.progress.total * 100);
    $('progress').hidden = false;
    $('progress').innerHTML = '<strong>Progress</strong>: ' + data.progress.done + ' / ' + data.progress.total + ' phases done' +
      '<div class="bar" role="progressbar" aria-valuenow="' + pct + '" aria-valuemin="0" aria-valuemax="100"><span style="width:' + pct + '%"></span></div>';
  } else if (data.phases.length) {
    $('progress').hidden = false; $('progress').className = 'warn';
    $('progress').textContent = 'The phase table has no Status column, so progress is not shown.';
  }
  if (data.mermaid) { $('diagram').hidden = false; $('phase-graph').textContent = data.mermaid; }
  $('overview').innerHTML = md(data.md);
  const list = $('phases');
  for (const p of data.phases) {
    const d = document.createElement('details');
    if (p.file) d.id = anchor(p.file);
    if (p.status && p.status !== 'done') d.open = ['implementing','testing','fixing','reviewing','awaiting-review','blocked'].includes(p.status);
    const todos = p.todos.total ? p.todos.done + '/' + p.todos.total + ' todos' : '';
    d.innerHTML = '<summary><span class="name">' + esc(p.number + '. ' + p.name) + '</span>' +
      (p.executor ? '<span class="todos">' + esc(p.executor) + '</span>' : '') +
      (todos ? '<span class="todos">' + todos + '</span>' : '') +
      (p.status ? '<span class="badge ' + cls(p.status) + '">' + esc(p.status) + '</span>' : '') + '</summary>' +
      '<div class="body">' + (p.missing ? '<p class="warn">Phase file not found: <code>' + esc(p.file) + '</code></p>' : p.md ? md(p.md) : '<p>No phase file linked.</p>') + '</div>';
    list.append(d);
  }
  addEventListener('hashchange', () => { const t = document.querySelector(location.hash); if (t && t.tagName === 'DETAILS') t.open = true; });
  if (typeof mermaid !== 'undefined') {
    const dark = matchMedia('(prefers-color-scheme: dark)').matches;
    mermaid.initialize({startOnLoad: false, securityLevel: 'strict', theme: dark ? 'dark' : 'default'});
    mermaid.run({querySelector: '.mermaid'}).catch(err => console.warn('mermaid:', err));
  }
})();
</script>
</body>
</html>
`;
}

// Keep plan.html out of Git with a per-plan .gitignore; never touch the project's root .gitignore.
export function ensureGitignore(dir, name = 'plan.html') {
  const file = path.join(dir, '.gitignore');
  const text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  if (text.split(/\r?\n/).some(line => line.trim() === name)) return false;
  fs.writeFileSync(file, text + (text && !text.endsWith('\n') ? '\n' : '') + name + '\n');
  return true;
}

// Best effort: open in the default browser, ignore failures (headless or remote sessions).
export function openInBrowser(file) {
  const [cmd, args] = process.platform === 'darwin' ? ['open', [file]] : process.platform === 'win32' ? ['cmd', ['/c', 'start', '""', file]] : ['xdg-open', [file]];
  try {
    const child = spawn(cmd, args, {detached: true, stdio: 'ignore'});
    child.on('error', () => {});
    child.unref();
  } catch { /* opening is optional; the path is printed either way */ }
}

export function main(argv) {
  const args = argv.filter(a => a !== '--open'), open = argv.includes('--open');
  if (args.length !== 1) {
    console.error('Usage: render-plan.mjs <plan-dir|file.md> [--open]');
    return 2;
  }
  let plan;
  try { plan = loadPlan(path.resolve(args[0])); } catch (err) { console.error(err.message); return 1; }
  const out = path.join(plan.dir, plan.output);
  fs.writeFileSync(out, renderHtml(plan));
  ensureGitignore(plan.dir, plan.output);
  for (const p of plan.phases.filter(p => p.missing)) console.warn(`warning: phase file not found: ${p.file}`);
  if (!plan.progress && plan.phases.length) console.warn('warning: phase table has no Status column; progress not shown');
  console.log(out);
  if (open) openInBrowser(out);
  return 0;
}

const invoked = process.argv[1] && fs.realpathSync(process.argv[1]) === fs.realpathSync(fileURLToPath(import.meta.url));
if (invoked) process.exitCode = main(process.argv.slice(2));
