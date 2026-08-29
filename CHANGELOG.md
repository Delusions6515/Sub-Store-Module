# Changelog

## v2.2.6 (105-573b3af-release)
- fix(action): 移除 APatch 的 clear 调用
  - APatch 管理器无法正常转义 clear 的输出
- fix(build): 修复 node 版本获取逻辑
  - 修复 node 最新 lts 版本尚未构建时，构建失败的问题

## v2.2.5 (103-b39aa75-release)
- ci: 调整缓存方式
- fix(action): 修改超时退出时间为 20 秒；添加单实例功能
  - 受限于管理器没有明确的退出事件，action 只能做到事后止损
  - ! 请使用 action 菜单自带的退出功能 ！
- feat(lib, config): 增加不安全的下载方式 & 优化 lib.sh:download 逻辑 (#10)
  - 当 lib:download curl,wget 方法不可用, 且 config `allow_nosafe_download` 为 `true` 时, 使用 root 环境提供的 `busybox wget` 来进行下载
  - 优化 lib:download, 改为 case 方便后续扩展

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

### Full Changelog
- [Commit history](https://github.com/Delusions6515/Sub-Store-Module/commits/main/)

