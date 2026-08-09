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
- service: 降权链成功路径加日志 (记录 setpriv/su/root 实际使用情况)
  - 之前只有失败有日志 (setpriv 不可用->su / 回退 root), setpriv 成功完全静默
  - 现在成功时输出 Info: 降权: /system/bin/setpriv (toybox, --init-groups) /
    - 任意 setpriv 路径, 便于收集各设备上 setpriv 可用性
  - 沙盒验证: 成功 Info / 失败 Warn 均正常
- chore(deps): bump ncipollo/release-action from 1.14.0 to 1.21.0 (#3)
- chore(deps): bump actions/checkout from 4 to 7 (#2)
- chore(deps): bump actions/upload-artifact from 4 to 7 (#1)
- chore(deps): 新增 dependabot 自动更新 GitHub Actions 依赖
- customize.sh: 升级安装时可选择是否覆盖二进制 (音量+ 覆盖 / 其他键跳过)
  - 检测到已有二进制时询问: 音量+ 用包内新版本覆盖, 其他键或 5 秒无按键
    - 跳过保留 (之后可用 [执行] 按钮更新); 全新安装直接拷贝, 无交互
  - 复用 action.sh 的 getevent+timeout 读键方式, 消费 UP 事件
  - 沙盒测试 5 场景: 全新/音量+覆盖/音量-跳过/超时跳过/UP消费 PASS
  - README: 安装说明补充升级交互
- node 始终使用官方最新 LTS 版本
  - fetch_node 改为解析 nodejs.org index.json 的当前 LTS (如 24.19.0),
    - 从 node-android-<arch>-<major> release 取对应版本 asset (release 已按大版本归档)
  - 最新 LTS 尚未构建时回退该大版本已有最高版本并告警
  - README/注释同步更新
- Update README.md
  - fix xream's Sub-Store for Magisk link.
- Update README.md
- README: 提醒 shell 低权限用户不走 VPN, 需要代理时设置 SUB_STORE_BACKEND_DEFAULT_PROXY
- 修复更新后 bundle 权限 600 root 导致低权限 node 无法读取: 更新脚本下载后 chmod, 服务启动前防御性归一权限
- 执行菜单: 主菜单加退出选项, 子菜单加返回上一级, 菜单改为循环结构 (操作后回主菜单)
- 降权链路修复: setpriv 功能实测 (仅 toybox 支持 --reuid, busybox 不行), su 2000 兜底; 数据目录迁移至 /data/local/sub_store (shell 域原生可访问, 不暴露 root), 移除 sepolicy 方案
- fix: update-json 生成到 json-out/ 独立目录, 避免 gh-pages checkout 时 untracked 文件冲突
- 修复脚本权限: sub_store.service/inotify 加入 chmod 列表, 所有脚本执行统一改用 sh 前缀 (不再依赖 +x)
- README: 配置拆分后不可覆盖安装 xream 原版, 局域网配置改为 env 全大写变量, 删除目录结构章节
- 执行菜单: 直达地址常驻 TUI 顶部 + 浏览器打开选项; 重绘改为 clear 全量重绘 (参考 funbox), 音量下键移动/音量上键确认
- 执行菜单修复: 渲染前清屏实时刷新, read_vol 内部消费 UP 事件避免重复刷新; SUB_STORE_FRONTEND_BACKEND_PATH 归入后端配置, 地址显示: 非合并后端也带路径前缀, 前端带 ?api= 参数
- fix: update-json 发布步骤首次创建 gh-pages 时 orphan checkout 后不再重复 checkout (pathspec 错误)
- 模块管理器更新支持: updateJson 按架构指向 gh-pages 上的 update-<abi>.json, tag 发布时 workflow 自动生成并推送
- 启动前自动修正低权限用户目录所有权; 配置修改未重启时提醒手动重启
- sub_store.env 全部环境变量动态导入服务进程 (不再硬编码导出列表, 新增 Docker 变量无需改脚本)
- 支持 APatch (APM): 执行按钮最低版本检查 Magisk>=27008 / KernelSU>=10670 / APatch>=11039
- 执行菜单重构: 顶层为查看地址/启动/停止/重启/开机自启开关, 更新选项收进子菜单; 支持合并模式地址显示
- 配置拆分: sub_store.config 只保留模块特有配置, 服务环境变量移至 sub_store.env (全大写, 与 Docker 版一致)
- module.prop 版本字段改为占位符, 版本名由 git tag 生成 (ZygiskNext 风格)
- 版本命名参考 ZygiskNext: versionCode=git 提交数, version 附带短 hash; 基线版本 1.0.0
- workflow: abi 改为 choice 类型 (GitHub 上显示为下拉选择而非手动输入)
- node 下载逻辑: 从 release 资产列表取真实下载地址
  - 原先按 tag 拼 URL; 改为:
  - 扫描全部 release, 按架构过滤 + sort -V 取版本号最大者
  - 再查该 release 的实际资产, 取 browser_download_url (顺带验证产物存在)
  - 资产缺失时给出明确报错
- 改为全在线构建 + node 低权限运行 + GitHub Actions
  - build.sh: 移除本地参考 zip 依赖, 所有组件在线获取
    - node 来自 node-android-build 仓库 release (NODE_REPO/NODE_DIST_URL/NODE_BIN_PATH 可覆盖)
    - 后端/前端/http-meta/mihomo 内核均取自各上游 latest release
    - 新增 TARGET_ABI 支持 (arm64-v8a 默认)
  - 低权限运行: node 默认以 shell(uid 2000) 运行 (setpriv, 回退 root)
    - 移除 chmod 777; run/ 与 http-meta/ 目录授权给运行用户
    - 配置文件收紧为 0600 root 专属
  - 新增 .github/workflows/build.yml: 手动触发 + 打 tag 自动构建发布
- 初始化 Sub-Store for Android 模块
  - 执行按钮 (action.sh): 音量键选择菜单
    - 全部更新 / 前后端 / 仅后端 / 仅前端 / http-meta
    - http-meta 子菜单: 全部 / js+tpl / mihomo 内核稳定版 / mihomo 内核预览版
  - 开机自启 (service.sh) + 模块开关联动 (inotifyd)
  - 配置对应 Docker 版环境变量 (sub_store.config)
  - 更新脚本: 后端 / 前端 / http-meta (版本对比 + 原子替换 + 自动重启)
  - 构建脚本 build.sh (从参考 zip 提取内置二进制 + 官方 module_installer.sh)
  - 遵循 Magisk / KernelSU 模块开发指南

### Full Changelog
- [Commit history](https://github.com/Delusions6515/Sub-Store-Module/commits/main/)

