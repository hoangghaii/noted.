#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const mode = process.argv[3];
function context(event, message) {
  console.log(JSON.stringify({hookSpecificOutput:{hookEventName:event,additionalContext:message}}));
}
function run(payload) {
  let input=payload.tool_input;
  if(typeof input==='string') {try{input=JSON.parse(input);}catch{return;}}
  if(!input||typeof input!=='object')return;
  if(mode==='search') {
    const command=input.command??input.cmd;
    if(typeof command!=='string')return;
    // Advisory only: inspect a simple search command; never block build/debug pipelines.
    if(/^\s*(rg|grep|find)\s/.test(command) && /(?:^|[\s/])(?:node_modules|\.git|__pycache__)(?:[/\s]|$)/.test(command))
      context('PreToolUse','This search includes generated or dependency directories. Prefer a scoped source search unless dependency investigation is intended.');
    return;
  }
  if(mode!=='modularization')return;
  const names=[];
  if(typeof input.file_path==='string')names.push(input.file_path);
  const patch=input.patch??input.command;
  if(typeof patch==='string') for(const m of patch.matchAll(/^\*\*\* (?:Add|Update) File: (.+)$/gm))names.push(m[1]);
  const cwd=path.resolve(payload.cwd||process.cwd());
  for(const name of new Set(names)) {
    const file=path.resolve(cwd,name);
    const rel=path.relative(cwd,file);
    if(rel.startsWith('..')||path.isAbsolute(rel))continue;
    try {
      const real=fs.realpathSync(file), realRel=path.relative(fs.realpathSync(cwd),real);
      if(realRel.startsWith('..')||path.isAbsolute(realRel))continue;
      const stat=fs.statSync(file);
      if(!stat.isFile()||stat.size>1024*1024)continue;
      const text=fs.readFileSync(file,'utf8');if(text.includes('\0'))continue;
      const lines=text.split('\n').length;
      if(lines>200)context('PostToolUse',`${rel} has ${lines} lines. Consider extracting cohesive modules if that improves this task.`);
    }catch{/* A deleted or unavailable file needs no advice. */}
  }
}
try {const raw=fs.readFileSync(0,'utf8');if(raw.trim())run(JSON.parse(raw));} catch {/* Malformed/unknown payloads must not interrupt work. */}
