#!/usr/bin/env node
'use strict';

/**
 * Optional Claude Code statusline (Node.js built-ins only, cross-platform).
 * Codex-style layout, built from the JSON Claude Code passes on stdin:
 *   Model effort · session name · 5h N% left · weekly N% left · N used · Context N% used · dir · branch
 * Fields that Claude Code omits (rate_limits, effort, session_name, ...) are skipped.
 * When a local Codex CLI has session logs, a second "Codex 5h · weekly · tokens · Context" row follows.
 */

const { stdin, env } = require('process');
const { execSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

// Claude Code reads the statusline through a pipe (never a TTY) and renders ANSI colors.
const USE_COLOR = !env.NO_COLOR;
const paint = (code, text) => (USE_COLOR ? `\x1b[${code}m${text}\x1b[0m` : text);
const SEP = paint('2', ' · ');

function exec(cmd, cwd) {
    try {
        return execSync(cmd, {
            cwd,
            encoding: 'utf8',
            stdio: ['ignore', 'pipe', 'ignore'],
            windowsHide: true,
            timeout: 1500
        }).trim();
    } catch (err) {
        return '';
    }
}

const isNum = (v) => typeof v === 'number' && Number.isFinite(v);

function formatTokens(n) {
    if (n >= 1e6) return `${(n / 1e6).toFixed(1).replace(/\.0$/, '')}M`;
    if (n >= 1e3) return `${Math.round(n / 1e3)}K`;
    return String(n);
}

// Green while plenty is left, yellow at <=25% left, red at <=10% left.
function leftColor(left) {
    if (left <= 10) return '31';
    if (left <= 25) return '33';
    return '32';
}

function rateLimit(label, window) {
    if (!window || !isNum(window.used_percentage)) return '';
    const left = Math.max(0, Math.round(100 - window.used_percentage));
    return paint(leftColor(left), `${label} ${left}% left`);
}

// Optional local integration only: never fetch/install a package from a statusline.
function ccusageCost() {
    if (!['1', 'true'].includes(env.AGENTKIT_CCUSAGE || '')) return '';
    try {
        const blocks = JSON.parse(exec('ccusage blocks --json') || '{}');
        const active = blocks.blocks?.find((b) => b.isActive === true);
        if (!active || !isNum(active.costUSD)) return '';
        const perHour = active.burnRate?.costPerHour;
        return paint('36', isNum(perHour)
            ? `$${active.costUSD.toFixed(2)} ($${perHour.toFixed(2)}/h)`
            : `$${active.costUSD.toFixed(2)}`);
    } catch (err) {
        return '';
    }
}

// Recent Codex rollout files, newest first, from the latest days of sessions/YYYY/MM/DD.
function recentCodexRollouts(sessionsDir, maxDays = 7, maxFiles = 40) {
    const sortedDirs = (dir) => fs.readdirSync(dir, { withFileTypes: true })
        .filter((e) => e.isDirectory()).map((e) => e.name).sort().reverse();
    const dayDirs = [];
    for (const y of sortedDirs(sessionsDir)) {
        for (const m of sortedDirs(path.join(sessionsDir, y))) {
            for (const d of sortedDirs(path.join(sessionsDir, y, m))) {
                dayDirs.push(path.join(sessionsDir, y, m, d));
                if (dayDirs.length >= maxDays) break;
            }
            if (dayDirs.length >= maxDays) break;
        }
        if (dayDirs.length >= maxDays) break;
    }
    return dayDirs
        .flatMap((dir) => fs.readdirSync(dir).filter((f) => f.endsWith('.jsonl')).map((f) => path.join(dir, f)))
        .map((f) => ({ f, t: fs.statSync(f).mtimeMs }))
        .sort((a, b) => b.t - a.t)
        .slice(0, maxFiles)
        .map((e) => e.f);
}

function readSlice(file, fromEnd, bytes) {
    const fd = fs.openSync(file, 'r');
    try {
        const size = fs.fstatSync(fd).size;
        const len = Math.min(bytes, size);
        const buf = Buffer.alloc(len);
        fs.readSync(fd, buf, 0, len, fromEnd ? size - len : 0);
        return buf.toString('utf8');
    } finally {
        fs.closeSync(fd);
    }
}

function lastTokenCount(file) {
    return readSlice(file, true, 256 * 1024).split('\n').reverse()
        .filter((l) => l.includes('"token_count"'))
        .map((l) => { try { return JSON.parse(l).payload; } catch (err) { return null; } })
        .find((p) => p && p.type === 'token_count');
}

function sessionCwd(file) {
    try {
        return JSON.parse(readSlice(file, false, 64 * 1024).split('\n')[0]).payload?.cwd || '';
    } catch (err) {
        return '';
    }
}

// Codex usage from local session logs: limits from the newest log of any project; tokens and
// context from the newest session that ran inside the current project (e.g. a kit-autopilot handoff).
function codexUsage(projectDir) {
    try {
        const home = env.CODEX_HOME || path.join(os.homedir(), '.codex');
        const files = recentCodexRollouts(path.join(home, 'sessions'));
        const parts = [];

        const latest = files.map(lastTokenCount).find(Boolean);
        if (latest) {
            const now = Date.now() / 1000;
            // The log is a snapshot: a window whose reset time has passed is fully available again.
            const live = (w) => (w ? { used_percentage: isNum(w.resets_at) && w.resets_at < now ? 0 : w.used_percent } : null);
            parts.push(rateLimit('5h', live(latest.rate_limits?.primary)));
            parts.push(rateLimit('weekly', live(latest.rate_limits?.secondary)));
        }

        const inProject = (cwd) => cwd && projectDir && (cwd === projectDir || cwd.startsWith(projectDir + path.sep));
        const projectFile = files.find((f) => inProject(sessionCwd(f)));
        const info = projectFile && lastTokenCount(projectFile)?.info;
        if (info) {
            const tokens = info.total_token_usage?.total_tokens;
            if (isNum(tokens) && tokens > 0) parts.push(paint('33', `${formatTokens(tokens)} used`));
            const inContext = info.last_token_usage?.total_tokens;
            const windowSize = info.model_context_window;
            if (isNum(inContext) && isNum(windowSize) && windowSize > 0) {
                const used = Math.min(100, Math.round(inContext * 100 / windowSize));
                parts.push(paint(leftColor(100 - used), `Context ${used}% used`));
            }
        }

        const shown = parts.filter(Boolean);
        return shown.length ? `${paint('37', 'Codex')} ${shown.join(SEP)}` : '';
    } catch (err) {
        return '';
    }
}

function render(data) {
    const parts = [];

    const model = data.model?.display_name || 'Claude';
    const effort = data.effort?.level;
    parts.push(paint('35', effort ? `${model} ${effort}` : model));

    if (data.session_name) parts.push(paint('34', data.session_name));

    parts.push(rateLimit('5h', data.rate_limits?.five_hour));
    parts.push(rateLimit('weekly', data.rate_limits?.seven_day));

    const ctx = data.context_window || {};
    const tokens = (isNum(ctx.total_input_tokens) ? ctx.total_input_tokens : 0)
        + (isNum(ctx.total_output_tokens) ? ctx.total_output_tokens : 0);
    if (tokens > 0) parts.push(paint('33', `${formatTokens(tokens)} used`));
    if (isNum(ctx.used_percentage)) {
        const used = Math.round(ctx.used_percentage);
        parts.push(paint(leftColor(100 - used), `Context ${used}% used`));
    }

    parts.push(ccusageCost());

    const dir = data.workspace?.current_dir || data.cwd || process.cwd();
    parts.push(paint('36', path.basename(dir) || dir));
    const branch = exec('git branch --show-current', dir) || exec('git rev-parse --short HEAD', dir);
    if (branch) parts.push(paint('32', branch));

    const codex = codexUsage(data.workspace?.project_dir || dir);
    // Claude Code renders each output line as its own statusline row.
    return parts.filter(Boolean).join(SEP) + (codex ? '\n' + codex : '');
}

function readStdin() {
    return new Promise((resolve, reject) => {
        const chunks = [];
        stdin.setEncoding('utf8');
        stdin.on('data', (chunk) => chunks.push(chunk));
        stdin.on('end', () => resolve(chunks.join('')));
        stdin.on('error', reject);
    });
}

readStdin()
    .then((input) => {
        const data = input.trim() ? JSON.parse(input) : {};
        console.log(render(data));
    })
    .catch((err) => {
        console.error('Error:', err.message);
        process.exit(1);
    });
