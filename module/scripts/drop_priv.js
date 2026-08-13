#!/usr/bin/env node
// 降权 preload
//
//   | env          | tip                        |
//   | ------------ | ---------------------------|
//   | DROP_UID     |   目标 uid (默认 2000)     |
//   | DROP_GID     |   主组 gid (默认 2000)     |
//   | DROP_GROUPS  |   附加组 GID , 逗号分隔    |
// ============================================================
'use strict';

const uid = Number(process.env.DROP_UID || '2000');
const gid = Number(process.env.DROP_GID || '2000');
const groups = (process.env.DROP_GROUPS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean)
  .map(Number);

if (
  !Number.isInteger(uid) || uid < 0 ||
  !Number.isInteger(gid) || gid < 0 ||
  groups.some((g) => !Number.isInteger(g) || g < 0)
) {
  console.error('drop_priv: invalid DROP_UID/DROP_GID/DROP_GROUPS');
  process.exit(1);
}

try {
  process.setgroups(groups);
  process.setgid(gid);
  process.setuid(uid);
} catch (err) {
  console.error('drop_priv: failed to drop privileges:', err);
  process.exit(1);
}