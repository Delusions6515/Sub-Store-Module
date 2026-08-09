# Changelog

## v2.0.7-hotfix.4 (60-9707a1c-hotfix)
- feat: 增加 http-meta 进程的 inet 组权限选项
  - 若运行 http-meta 时使用 `su 2000 -g 2000 -G 3003`(带 inet 组)，则 http-meta 的流量也会走 Android VPN
  - 但是一般使用场景下，http-meta 应该不被代理
  - 所以本提交添加了 `run_http_meta_with_inet` 选项，用于控制运行 http-meta 时是否带 inet 组
  - 效果：
    - `false`(默认)：不带 inet 组，http-meta 流量不走 VPN
    - `true`：带 inet 组，http-meta 可用系统 DNS 但流量走 VPN
- fix: 降权逻辑加入 inet 组，修复 shell 情况下的 DNS 解析问题
  - 此版本开始，默认用户回退 shell (su 2000 -g 2000 -G 3003)
- fix: updateJson 生成修正 (version 去 v 前缀, zipUrl 构建类型对齐 release/hotfix)
  - Co-Authored-By: Claude <noreply@anthropic.com>

## v2.0.7-hotfix.3 (57-8745b44-hotfix)
- fix: 将默认运行用户改为 root, 并在 TUI 中增加安全提醒
  - 之前设置为 shell 用户，网络访问可能受限
  - 但我不推荐直接使用 root 用户运行
  - 建议更改 run_as_user 为 shell 用户，并在 sub_store.env 中配置代理
- refactor: 重构 action.sh，添加后台执行操作功能，支持实时显示 run.log 输出

## v2.0.7-hotfix.2 (55-7c8160c-hotfix)
- fix: 执行菜单支持管理器返回键退出，非 KSU/AP 用户采用空行滚屏
  - read_vol 识别 BACK 键并退出菜单
  - clear_screen 非 KSU/AP 管理器不再用 clear 命令：Magisk 管理器终端不支持 ANSI 转义，会输出 \033[H\033[J 原文

## v2.0.7-hotfix.1 (54-94dc6a8-hotfix)
- ci: hotfix tag 不再按 prerelease 处理
  - 仅 alpha/beta/rc 视为预发布；hotfix 为稳定版修订（build-type=hotfix）
- fix: action.sh 服务操作统一写入 run.log
  - action.sh 主菜单 start/stop/restart 追加 run.log / run_error.log
  - lib.sh restart_service/stop_service 同样追加（覆盖更新与 regenerate 流程）
- hotfix: disable webui build for 2.0.7 release
- ci: split webui build from module packaging
- build: integrate webui assets into module package
- refactor(ci): 更新构建工作流以支持构建类型和预发布标记
- chore: 优化 GitHub 标签创建逻辑
- chore: 更新问题反馈模板
- feat: 添加 Issue 模板 (Bug/功能建议/使用求助/其他) 与模板遵循检查 Action
  - 禁止空白 Issue, 强制从模板创建
  - Bug 模板: 仅受理最新版本, 设备与环境信息合并, 含相关配置/日志章节
  - Action: 不合规自动打「未遵循模板」标签, 每周一 0 点自动关闭

### Full Changelog
- [Commit history](https://github.com/Delusions6515/Sub-Store-Module/commits/main/)

