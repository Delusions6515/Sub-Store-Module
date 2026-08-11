# Changelog

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

## v2.1.0 (74-768fd15-release)
- fix: 修正 Issue 模板检查工作流条件逻辑
- feat: 增加更新状态检查功能，优化更新日志处理
- chore(docs): update README.md
- ci: 推送到 main 分支时自动触发工作流
- feat: 更新 mihomo 稳定版 tag 获取逻辑，使用 version.txt 作为回退方案
- ci: 重构构建脚本与工作流
- feat: 更新输出统一进 update.log，重启操作日志(run.log)收尾追加进 update.log，
  - TUI 与 WebUI 更新页看到同一份日志。
- fix: CHANGELOG 生成保留层级缩进, 并并入最新稳定系列的 hotfix
  - tag_section 不再 strip 掉 body 的缩进, 按源层级 +2 空格对齐, 修复深层子弹被抹平
  - 新增 --with-hotfix: 稳定版窗口并入最新稳定 tag 的 hotfix 系列, hotfix 发布也会刷新 CHANGELOG
  - Co-Authored-By: Claude <noreply@anthropic.com>
- feat: 增加 http-meta 进程的 inet 组权限选项
  - 若运行 http-meta 时使用 `su 2000 -g 2000 -G 3003`(带 inet 组)，则 http-meta 的流量也会走 Android VPN
  - 但是一般使用场景下，http-meta 应该不被代理
  - 所以本提交添加了 `run_http_meta_with_inet` 选项，用于控制运行 http-meta 时是否带 inet 组
  - 效果：
    - `false`(默认)：不带 inet 组，http-meta 流量不走 VPN
    - `true`：带 inet 组，http-meta 可用系统 DNS 但流量走 VPN
- fix: 降权逻辑加入 inet 组，修复 shell 情况下的 DNS 解析问题
  - 此版本开始，默认用户回退 shell (su 2000 -g 2000 -G 3003)
- chore(docs): update README
- chore: 安装脚本新增 WebUI 相关提示文本
- fix: updateJson 生成修正 (version 去 v 前缀, zipUrl 构建类型对齐 release/hotfix)
  - Co-Authored-By: Claude <noreply@anthropic.com>
- fix: 将默认运行用户改为 root, 并在 TUI 中增加安全提醒
  - 之前设置为 shell 用户，网络访问可能受限
  - 但我不推荐直接使用 root 用户运行
  - 建议更改 run_as_user 为 shell 用户，并在 sub_store.env 中配置代理
- refactor: 重构 action.sh，添加后台执行操作功能，支持实时显示 run.log 输出
- feat: webui.sh 所有操作写入日志，并添加 log-size 方法方便前端调用
- fix: 执行菜单支持管理器返回键退出，非 KSU/AP 用户采用空行滚屏
  - read_vol 识别 BACK 键并退出菜单
  - clear_screen 非 KSU/AP 管理器不再用 clear 命令：Magisk 管理器终端不支持 ANSI 转义，会输出 \033[H\033[J 原文
- fix: action.sh 服务操作统一写入 run.log
  - action.sh 主菜单 start/stop/restart 追加 run.log / run_error.log
  - lib.sh restart_service/stop_service 同样追加（覆盖更新与 regenerate 流程）
- refactor: 操作日志轮转统一为 lib.sh 的 rotate_run_log
  - 新增 rotate_run_log：归档 run.log / run_error.log 为 .bak
  - webui.sh start/stop/restart 在重定向前轮转（mv 后 fd 不会指向旧文件）
  - start.sh 改用同一函数，删除重复的 mv
  - 移除 webui.sh 的 log-reset 子命令
- feat: 日志改为归档制，log-reset 后新 run.log 只含本次操作
  - 新增 log-reset：归档 run.log / run_error.log 为 .bak（与开机 start.sh 行为一致）
  - log 子命令简化为输出当前文件全部内容（配合归档即为本次操作日志）
  - 移除行号偏移方案（日志轮转会使行号失效）
- feat: 服务控制输出统一追写 run.log，支持异步触发
  - start/stop/restart 输出追加到 run.log / run_error.log（与 start.sh、inotify 行为一致）
  - WebUI 可后台执行（nohup &）后轮询状态、读取日志，避免同步等待
- fix: 修复 stop 退出码，webui.sh 增加 log 子命令
  - stop_service 的 kill 调用判空：进程已退出时不再因 kill 无参数报错导致退出码非 0
  - webui.sh 新增 log 子命令：输出 run.log / run_error.log 尾部，供 WebUI 展示操作日志
- feat: 添加 WebUI 脚本入口并重构 action.sh 和 lib.sh 中的功能

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

### Full Changelog
- [Commit history](https://github.com/Delusions6515/Sub-Store-Module/commits/main/)

