# Changelog

## v2.0.6 (43-33c9fe4-release)
- fix: 修复开机误报"配置已修改但未重启"
- feat(action): 添加配置修改提醒功能，提示用户重启以应用新配置
- refactor(service): 让 sub_store.service 的降权回退逻辑更有可读性
- fix(ci): 修正 CHANGELOG.md 中的缩进格式
- chored(docs): update README.md

## v2.0.5 (38-a4de368-release)
- feat: action.sh: 重构为函数结构 + 状态每轮实时刷新
- fix: update default config - 旧版默配置实际无法正常连接到后端
- chore(module): Update sinstall script & module.prop
- workflow: 生成 CHANGELOG.md (最近 4 个 tag) + release notes 用提交列表替代固定文案
  - update-json job 生成 CHANGELOG.md (每个 tag 相对上一 tag 的新提交, 只保留最近 4 个 tag), 随 update JSON 发布到 gh-pages; update JSON 的 changelog 指向 gh-pages 的 CHANGELOG.md
  - build job 生成 release notes: 当前 tag 提交列表作为 release body (替代固定文案), Ensure release 用 notes-file 创建/更新
  - zip 命名统一带 ABI 后缀 (build.sh 与 update JSON 对齐), gh-pages commit 身份改用 github-actions[bot]

## v2.0.4 (34-94468d7-release)
- 默认合并模式 + 修复分离模式前缀访问 (对齐官方 Docker) + merge 布尔归一
  - sub_store.env: SUB_STORE_BACKEND_MERGE 默认 true (官方 Docker 默认一致),
  - 安装提示/README 同步; 分离模式=注释该行
  - action.sh 直达地址: 分离模式 + 前缀时 ?api= 指向前端端口+前缀
  - (官方文档: http://127.0.0.1:3001?api=http://127.0.0.1:3001/<前缀>),
  - 之前拼成后端端口+前缀导致前端连不上后端 (后端分离模式无前缀)
  - service 导入: SUB_STORE_BACKEND_MERGE true-only 导出, 设 false 也能关闭合并
  - (后端 truthy 判断, xream 模块设 false 同样会合并)

## v2.0.3 (33-572a7de-release)
- service: su 降权加可用性实测 (su 2000 -c id 成功才采用)
  - command -v su 存在 != su 2000 -c 可用 (不同 root 方案行为可能不同),
  - 与 setpriv 同原则: 功能实测成功才进 su 模式, 失败回退 root 并告警
  - su 可用日志级别从 Warn 降为 Info (正常降权路径); 均不可用才 Warn
  - 沙盒验证 3 场景: su 可用/su 不可用/setpriv 正常 均正确
- workflow: 修复并行 job 共用 release tag 的创建竞态 (422 already_exists)
  - 4 个 ABI job 并行 Upload release 用同一 tag, 同时 GET 不到 -> 同时 POST,
  - 后到者报 already_exists (x86 构建最慢稳定失败)
  - 新增 Ensure release step: gh release create 抢建, 并发失败 || true 消化;
  - Upload 步骤只做 allowUpdates 更新上传

### Full Changelog
  - [Commit history](https://github.com/Delusions6515/Sub-Store-Module/commits/main/)

