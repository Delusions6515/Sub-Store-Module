# Changelog

## v2.2.4 (100-c283334-release)
- chore(docs): update README.md
- chore: module.prop 更新 author，新增 lanyi233
  - @lanyi233 实现了 node 降权的所有逻辑
- feat(config): 增加 http-meta 运行开关参数 (#9)
  - Co-authored-by: Delusions6515 <213381333+Delusions6515@users.noreply.github.com>
- fix(service): 让 node 降权进程脱离调用会话 (#8)

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

### Full Changelog
- [Commit history](https://github.com/Delusions6515/Sub-Store-Module/commits/main/)

