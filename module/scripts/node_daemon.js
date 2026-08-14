#!/usr/bin/env node
'use strict';

const { fchmodSync, fchownSync, openSync } = require('node:fs');
const { spawn } = require('node:child_process');

const [nodePath, preloadPath, scriptPath, stdoutPath, stderrPath] = process.argv.slice(2);

if (![nodePath, preloadPath, scriptPath, stdoutPath, stderrPath].every(Boolean)) {
  console.error('node_daemon: usage: <node> <preload> <script> <stdout> <stderr>');
  process.exit(1);
}

function parseId(value, name) {
  if (value === undefined || value === '') return 2000; // Default 2000:shell
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 0) {
    console.error(`node_daemon: invalid ${name}: ${value}`);
    process.exit(1);
  }
  return parsed;
}

const dropUid = parseId(process.env.DROP_UID, 'DROP_UID');
const dropGid = parseId(process.env.DROP_GID, 'DROP_GID');

let stdout;
let stderr;
try {
  stdout = openSync(stdoutPath, 'a');
  stderr = openSync(stderrPath, 'a');
} catch (err) {
  console.error('node_daemon: failed to open log files:', err.message);
  process.exit(1);
}
try {
  for (const fd of [stdout, stderr]) {
    fchownSync(fd, dropUid, dropGid);
    fchmodSync(fd, 0o644);
  }
} catch (err) {
  console.error('node_daemon: failed to prepare log files:', err.message);
  process.exit(1);
}

const child = spawn(nodePath, [`--require=${preloadPath}`, scriptPath], {
  detached: true,
  stdio: ['ignore', stdout, stderr],
  env: process.env,
});

child.once('error', (err) => {
  console.error('node_daemon: failed to spawn child:', err.message);
  process.exit(1);
});

child.once('spawn', () => {
  child.unref();
  process.exit(0);
});
