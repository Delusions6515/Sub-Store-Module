# Changelog

## v2.4.0 (119-8bef714-release)
- fix: stabilize http-meta VPN bypass
- fix: keep action results visible
- fix: bypass auto_redirect with connmark
- fix: use connmark for transparent proxy bypass
- feat: apply optional http-meta extra fwmark
- feat: add optional http-meta extra fwmark
- docs: document http-meta VPN bypass
- fix: tolerate missing IPv6 iptables
- feat: bypass Android VPN for http-meta
- feat: add http-meta VPN bypass option

## v2.3.1 (109-357d66b-release)

## v2.3.0 (109-d08661e-release)
- feat(lib): 添加后端路径检查和 CORS 来源验证功能
- feat(scripts): add pid file support and duplicate run check (#12)
- chore(ci): 仅在 dev 分支推送时触发 canary 构建
- feat(service): 支持保存 pid 并据此停止/判断是否正在运行

## v2.2.6 (105-573b3af-release)
- fix(action): 移除 APatch 的 clear 调用
  - APatch 管理器无法正常转义 clear 的输出
- fix(build): 修复 node 版本获取逻辑
  - 修复 node 最新 lts 版本尚未构建时，构建失败的问题

### Full Changelog
- [Commit history](https://github.com/Delusions6515/Sub-Store-Module/commits/main/)

