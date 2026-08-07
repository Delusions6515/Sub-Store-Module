# Changelog

## v2.0.7 (45-fbf2ee8-release)
- chore(docs): update README.md
- feat: 添加自动生成 SUB_STORE_FRONTEND_BACKEND_PATH 功能（/<20~24位随机字符串>）

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

### Full Changelog
  - [Commit history](https://github.com/Delusions6515/Sub-Store-Module/commits/main/)

