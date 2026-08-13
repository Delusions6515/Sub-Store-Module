# Changelog

## v2.2.3 (96-45513be-release)
- feat: 安装脚本新增追加新配置功能
- feat: 新增降权方式配置 `drop_priv_method`
  - KSU/AP 可用 `su`(默认)|`node`，Magisk 仅可用 `node`
  - 同时修复使用 node 降权导致在 KSU/AP 环境下 Sub-Store 卡死的问题
  - 更新 README.md
- fix: 修复 root 启动时 Sub-Store 卡住的问题
  - 不推荐使用 root 用户运行！
- fix(ci): 修复发布说明生成逻辑

## v2.2.2 (92-cdcc812-release)
- chore(ci): Release Notes 中的 CHANGELOG部分 回退为2级标题
- ci: 更新发布说明生成逻辑

## v2.2.1 (90-de1e0a1-release)
- chore: 调整日志输出顺序
- fix(service): 修复降权逻辑 (#7)
  - 使用 `node --require` 在 node 进程启动后, Sub-Store 运行前自我降权

## v2.2.0 (88-138cb92-release)
- test: 降权逻辑区分 Magisk 和 (KSU/AP) 模式，并打印日志
  - ~~尝试修复 Magisk 的降权但是没修好~~
- fix: fix syntax error
- fix: 添加条件以避免在缓存命中时重复设置 pnpm 和 Node.js
- feat: 优化降权逻辑和降权日志输出
- refactor: action 重构 run_op 方法，接收 update/run 参数
  - 并修复重启等操作在 action 没有日志的问题
- fix: action 只在按键后重绘，超时静默等待，修复 Magisk 用户无操作依然滚屏的问题
  - KSU/AP 其实也有，但是被 clear 掩盖了（
- feat: WebUI 添加编辑 sub_store.env 功能
- chore(deps): 更新 dependabot 配置，设置目标分支为 dev
- chore(ci): 增加 WebUI commit hash 缓存功能，优化构建流程
- chore(docs): update README.md
- chore: dev 分支推送也触发 canary 构建
- chore(deps): bump actions/setup-node from 4 to 7 (#6)
- chore(deps): bump pnpm/action-setup from 4 to 6 (#5)
- chore(deps): bump actions/download-artifact from 7 to 8 (#4)

### Full Changelog
- [Commit history](https://github.com/Delusions6515/Sub-Store-Module/commits/main/)

