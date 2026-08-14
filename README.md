# Sub-Store for Android (Magisk / KernelSU / APatch 模块)

在 Android 上以系统级服务运行 [Sub-Store](https://github.com/sub-store-org/Sub-Store)（含 HTTP-META），  
并内置一键更新能力：
- 在 Magisk / KernelSU / APatch 管理器中点击模块的 **[执行]** 按钮，即可用音量键选择更新项。
- 在 KernelSU / Apatch 管理器中点击模块的 WebUI 按钮，即可进入 WebUI，更新页选择更新功能

注意：
- 本模块 ID 与旧版 `sub_store` 相同，但配置格式已变更（拆分为 `sub_store.config` + `sub_store.env`），
  **不支持直接覆盖安装 xream 原版模块**；升级前请先卸载旧版并迁移配置
- 开发严格遵循官方指南：[Magisk Developer Guides](https://topjohnwu.github.io/Magisk/guides.html) / [KernelSU Module Guide](https://kernelsu.org/guide/module.html) / [APatch APM Guide](https://apatch.dev/apm-guide.html)
- 脚本基于 xream 的 [Sub-Store for Magisk, KernelSU & APatch](https://t.me/zhetengsha/1008) 重新开发（GPL-3.0）

## 功能

| 功能 | 说明 |
| --- | --- |
| 开机自启 | `service.sh` 在系统启动完成后自动拉起 Sub-Store 后端 / 前端 / HTTP-META |
| 低权限运行 | node 默认以 `shell` (uid 2000) 较低权限运行（含 `inet` 组）；<br> 可选以 `root` 身份运行（会有安全警告）；<br> 数据目录位于 `/data/local/sub_store`（shell 域原生可访问，不暴露 root） |
| 执行按钮 | 管理器内点击 **[执行]**，按音量键选择操作（音量下键 移动 / 音量上键 确认） |
| WebUI | Vue 3 + Vite + [miuix-vue](https://github.com/YuKongA/miuix-vue) 构建的 WebUI <br> KSU/AP 管理器可直接使用管理器内置 WebUI 功能， <br> Magisk 用户可尝试：[KsuWebUIStandalone](https://github.com/KOWX712/KsuWebUIStandalone/releases) 或 [WebUI X](https://github.com/MMRLApp/WebUI-X-Portable/releases) |
| 全部更新 | Sub-Store 前后端 + http-meta 一次搞定 |
| 拆分更新 | 后端 / 前端 / http-meta 可单独更新 |
| http-meta 子菜单 | 全部更新 / 仅 js+tpl.yaml / 仅 mihomo 内核(稳定版) / 仅 mihomo 内核(预览版) |
| 开关联动 | 禁用模块自动停止服务，启用自动重启 |
| 配置保留 | 升级模块不覆盖 `/data/local/sub_store` 数据与配置 |
| 合并端口 | 默认开启（与官方 Docker 一致）；后端按**非空即合并**判断，设 `"false"` 无效；分离模式=注释该行 |
| 路径随机化 | 首次安装自动生成随机 `SUB_STORE_FRONTEND_BACKEND_PATH`（20~24 位字母数字）； <br> 检测到仍在使用模块默认值时 TUI 常驻告警，可一键重新生成（自动重启生效） |

## 安装

1. 执行 `./build.sh` 构建模块 zip，或使用已构建产物：
   - stable/alpha/beta/rc: [GitHub Releases](https://github.com/Delusions6515/Sub-Store-Module/releases)
   - canary: [GitHub Actions](https://github.com/Delusions6515/Sub-Store-Module/actions/workflows/build.yml?query=branch%3Adev+branch%3Amain)
2. Magisk / KernelSU / APatch 管理器 → 模块 → 从本地安装
3. 重启设备

> **升级安装时**：检测到已有二进制会询问是否用包内新版本覆盖——
> **音量+ = 覆盖**（用包内二进制替换现有）/ **其他键或 5 秒无按键 = 跳过**（保留现有，之后用 [执行] 按钮更新）。
> 全新安装自动拷贝内置二进制，无需交互。

> 管理器版本要求（执行按钮支持）：**Magisk >= 27008** / **KernelSU >= 10670** / **APatch >= 11039**
> 已安装的模块可在管理器内直接检查更新（`updateJson` 按架构区分，发布新 tag 后自动生效）

> ⚠️ **v2.0.0 破坏性变更**：数据/配置目录从 `/data/adb/sub_store` 迁移到 `/data/local/sub_store`
> （低权限用户原生可访问且不暴露 root）。v1.x 升级需手动迁移旧数据，或卸载后全新安装。

启动后访问（默认**合并模式**，单端口）：

- Sub-Store：<http://127.0.0.1:3001>
- HTTP-META：<http://127.0.0.1:9876>

> 分离模式（注释 `sub_store.env` 里的 `SUB_STORE_BACKEND_MERGE` 后）：  
> 前端 <http://127.0.0.1:3002> / 后端 <http://127.0.0.1:3001>

局域网访问：修改 `sub_store.env` 中的 `SUB_STORE_BACKEND_API_HOST` 为 `0.0.0.0` 后重启服务。

## 执行按钮（音量键菜单）

管理器 → 模块 → Sub-Store for Android → **[执行]**

```
主菜单 (前后端直达地址常驻显示在顶部):
  > 浏览器打开直达地址
    启动 Sub-Store
    停止 Sub-Store
    重启 Sub-Store
    生成并替换 SUB_STORE_FRONTEND_BACKEND_PATH
    禁用/启用开机自启 (显示当前状态)
    更新选项 ...
    退出

更新子菜单:
  > 全部更新 (Sub-Store 前后端 + http-meta)
    更新 Sub-Store 前后端
    仅更新 Sub-Store 后端
    仅更新 Sub-Store 前端
    更新 http-meta ...
    返回上一级

http-meta 子菜单:
  > [默认] 全部更新 (js + tpl.yaml + mihomo 内核)
    只更新 http-meta (js + tpl.yaml)
    只更新 mihomo 内核 (稳定版)
    只更新 mihomo 内核 (Prerelease-Alpha 预览版)
    返回上一级
```

- **直达地址**：TUI 顶部常驻显示前后端本机地址（合并模式显示单端口；配置了 `SUB_STORE_FRONTEND_BACKEND_PATH` 时，分离模式前端 `?api=` 指向前端端口+前缀、后端直连无前缀）
- **浏览器打开直达地址**：调用默认浏览器打开直达地址（非合并模式打开前端），解决终端内不可复制的问题
- 音量下键 切换到下一个选项，音量上键 确认
- 操作完成后返回主菜单，选择**退出**结束；子菜单可用**返回上一级**回退
- 5 分钟无按键自动退出

## 配置

配置文件位于 `/data/local/sub_store/scripts/`（修改后执行
`su -c "sh /data/adb/modules/sub_store/scripts/sub_store.service restart"`）：

- **`sub_store.config`**：仅模块特有配置（路径、运行用户等）
- **`sub_store.env`**：服务环境变量，全大写命名、与 Docker 版一致
  （内容与注释参考 [xream/sub-store](https://hub.docker.com/r/xream/sub-store) Docker 介绍）；
  **文件中定义的所有变量都会在服务启动时导入进程**，Sub-Store 新增环境变量直接加进文件即可，无需改脚本

修改配置后请**重启服务生效**；服务启动时会自动修正低权限用户（`run/`、`http-meta/`）的目录所有权，
若配置已修改但未重启，运行更新等操作时会收到提醒。

> 🔒 **`SUB_STORE_FRONTEND_BACKEND_PATH`**：首次安装时会自动替换为随机值（20~24 位字母数字），  
> 旧版默认值所有安装者都一样，等同公开路径。若 env 中仍为模块默认值，执行菜单顶部会常驻告警，  
> 可用 **生成并替换 SUB_STORE_FRONTEND_BACKEND_PATH** 一键重新生成（生成后自动重启生效）。

> ⚠️ http-meta 默认直连不走 VPN；如需其走 VPN（同时可用系统 DNS），在 `sub_store.config` 中设 `run_http_meta_with_inet="true"`。

`sub_store.config` 中的模块配置：

| 配置变量 | 说明 |
| --- | --- |
| `sub_store_path` 等路径变量 | 模块路径（一般不需要修改） |
| `run_as_user` | 运行用户： <br> `shell`(uid `2000` 低权限)  <br> `root`/置空=root |
| `drop_priv_method` | shell 用户降权方式：<br> `su`：启动前经 `su 2000` 切换（KSU/APatch 推荐）；<br> `node`：Node preload 自降权（KSU/APatch 经 `su 0 -c` 启动；Magisk 推荐） |
| `run_http_meta` | 是否运行 http-meta `true`(默认)/`false` |
| `run_http_meta_with_inet` | http-meta 是否授予 `inet` 组（仅 `shell` 用户生效）：<br> `false`(默认) 流量直连不走 VPN；<br> `true` 可用系统 DNS 但流量走 VPN |
| `allow_nosafe_download` | 是否允许不安全的下载方式 `true`/`false`(默认) : 用于更新时在所有下载方式不可用时降级使用 root 环境提供的 `busybox wget` 下载 (可能存在安全风险) |
| `enable_legacy_support` | 兼容模式 `false`/`true`/`backendport_backendpath`： 为基于 Sub Store for Magisk (xream) 模块的第三方工具提供兼容 <br> `false` 关闭<br> `true` 开启<br> `backendport_backendpath` 将后端路径拼接到后端端口以兼容部分工具读取 |


## 手动操作

```sh
su -c "sh /data/adb/modules/sub_store/scripts/sub_store.service start"    # 启动
su -c "sh /data/adb/modules/sub_store/scripts/sub_store.service stop"     # 停止
su -c "sh /data/adb/modules/sub_store/scripts/sub_store.service restart"  # 重启
su -c "sh /data/adb/modules/sub_store/scripts/update_backend.sh"          # 更新后端
su -c "sh /data/adb/modules/sub_store/scripts/update_frontend.sh"         # 更新前端
su -c "sh /data/adb/modules/sub_store/scripts/update_http_meta.sh all"    # 更新 http-meta
```

> 在 `/data/local/sub_store/manual` 创建空文件可禁止开机自启（手动控制）。

## 卸载

管理器删除模块即可：服务会自动停止，`/data/local/sub_store` 数据保留（如需彻底删除请手动删除该目录）。

## 构建

### GitHub Actions（推荐）

- 手动触发：Actions → Build Sub-Store module → Run workflow，可选 ABI 与版本号
- 推送 `v*` tag：自动构建并发布 release
- workflow 会额外 checkout [Delusions6515/Sub-Store-Module-WebUI](https://github.com/Delusions6515/Sub-Store-Module-WebUI)，构建后自动写入模块包内 `webroot/`
- 所有组件在线获取，无需本地参考文件
  - node 二进制来自 [Delusions6515/node-android-build](https://github.com/Delusions6515/node-android-build) 的 release

### 本地构建

```sh
./build.sh                    # 版本名取最近 git tag (如 v1.0.0), arm64-v8a
./build.sh 1.0.0              # 指定版本名覆盖 tag
TARGET_ABI=armeabi-v7a ./build.sh 1.0.0   # 指定 ABI
BUILD_TYPE=hotfix ./build.sh 1.0.1-hotfix1
NODE_BIN_PATH=~/node ./build.sh            # 本地 node 二进制 (调试用)
WEBUI_REPO_DIR=../Sub-Store-Module-WebUI ./build.sh
WEBUI_DIST_DIR=/path/to/webui/dist ./build.sh
```

- 版本命名参考 ZygiskNext（`module.prop` 中 `version`/`versionCode` 为占位符，不硬编码）：
  构建时自动生成 `version=1.0.0 (<git提交数>-<短hash>-release)`、`versionCode=<git提交数>`；
  版本名取最近 git tag（自动去 `v` 前缀），可用参数/`BUILD_TYPE` 覆盖

- WebUI 集成：
  - 默认查找相邻仓库 `../Sub-Store-Module-WebUI`，执行 `pnpm install` + `pnpm build`
  - 构建产物会自动复制到模块最终包内的 `webroot/`
  - 只想复用现成前端产物时，可用 `WEBUI_DIST_DIR=/path/to/dist` 直接指定 dist 目录
  - 若未发现 WebUI 仓库/产物，则跳过 WebUI 打包，不影响纯模块构建

- 组件来源：
  - **node**：始终使用官方最新 LTS 版本——从 `nodejs.org` 解析当前 LTS（如 `24.19.0`），
    再到 `NODE_REPO`（默认 [Delusions6515/node-android-build](https://github.com/Delusions6515/node-android-build)）的
    `node-android-<arch>-<major>` release 取对应版本 asset（该仓库 release 按 `大版本`+`<arch>` 归档、
    全部 4 架构、历史版本保留）；最新 LTS 尚未构建时回退该大版本已有最高版本并告警；
    可用 `NODE_DIST_URL` / `NODE_BIN_PATH` 覆盖
  - **后端**：[sub-store-org/Sub-Store](https://github.com/sub-store-org/Sub-Store) latest release
  - **前端**：[sub-store-org/Sub-Store-Front-End](https://github.com/sub-store-org/Sub-Store-Front-End) latest release
  - **http-meta**：[xream/http-meta](https://github.com/xream/http-meta) latest release + [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) 稳定版内核
- 构建产物默认输出到当前目录的 `build/` 下（可用 `OUT_DIR` 覆盖）
- `-hotfix` 后缀按稳定版修订处理：会进入正式 release/update JSON 渠道，不会被当成 prerelease
- 自动下载官方 `module_installer.sh` 生成 META-INF（恢复模式刷入用），失败时跳过（管理器安装不受影响）

## 许可

GPL-3.0。本模块脚本基于 xream 的 [Sub-Store for Magisk, KernelSU & APatch](https://t.me/zhetengsha/1008) 重新开发；
Sub-Store / HTTP-META / mihomo 版权归其各自作者所有。
