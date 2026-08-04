# Sub-Store for Android (Magisk / KernelSU 模块)

在 Android 上以系统级服务运行 [Sub-Store](https://github.com/sub-store-org/Sub-Store)（含 HTTP-META），
并内置一键更新能力：在 Magisk / KernelSU 管理器中点击模块的 **[执行]** 按钮，即可用音量键选择更新项。

- 模块 ID 与旧版 `sub_store` 相同，可直接覆盖升级 xream 原版模块，配置文件自动保留
- 开发严格遵循官方指南：[Magisk Developer Guides](https://topjohnwu.github.io/Magisk/guides.html) / [KernelSU Module Guide](https://kernelsu.org/guide/module.html)
- 脚本基于 xream 的 [Sub-Store for Magisk](https://github.com/xream/Sub-Store-for-Magisk) 重新开发（GPL-3.0）

## 功能

| 功能 | 说明 |
| --- | --- |
| 开机自启 | `service.sh` 在系统启动完成后自动拉起 Sub-Store 后端 / 前端 / HTTP-META |
| 低权限运行 | node 默认以 `shell` (uid 2000) 低权限运行，不授予多余权限 |
| 执行按钮 | 管理器内点击 **[执行]**，按音量键选择操作（VOL+ 下一个 / VOL- 确认） |
| 全部更新 | Sub-Store 前后端 + http-meta 一次搞定 |
| 拆分更新 | 后端 / 前端 / http-meta 可单独更新 |
| http-meta 子菜单 | 全部更新 / 仅 js+tpl.yaml / 仅 mihomo 内核(稳定版) / 仅 mihomo 内核(预览版) |
| 开关联动 | 禁用模块自动停止服务，启用自动重启 |
| 配置保留 | 升级模块不覆盖 `/data/adb/sub_store` 数据与配置 |

## 安装

1. 执行 `./build.sh` 构建模块 zip（或使用已构建产物）
2. Magisk / KernelSU 管理器 → 模块 → 从本地安装
3. 重启设备

启动后访问：

- 前端：<http://127.0.0.1:3001>
- 后端：<http://127.0.0.1:3000>
- HTTP-META：<http://127.0.0.1:9876>

局域网访问：修改配置 `sub_store_backend_host` 为 `0.0.0.0` 后重启服务。

## 执行按钮（音量键菜单）

管理器 → 模块 → Sub-Store for Android → **[执行]**

```
主菜单:
  > 全部更新 (Sub-Store 前后端 + http-meta)
    更新 Sub-Store 前后端
    仅更新 Sub-Store 后端
    仅更新 Sub-Store 前端
    更新 http-meta

http-meta 子菜单:
  > [默认] 全部更新 (js + tpl.yaml + mihomo 内核)
    只更新 http-meta (js + tpl.yaml)
    只更新 mihomo 内核 (稳定版)
    只更新 mihomo 内核 (Prerelease-Alpha 预览版)
```

- VOL+ 切换到下一个选项，VOL- 确认
- 5 分钟无按键自动退出

## 配置

配置文件：`/data/adb/sub_store/scripts/sub_store.config`（修改后执行
`su -c "sh /data/adb/modules/sub_store/scripts/sub_store.service restart"`）

环境变量对应 Docker 版（[xream/sub-store](https://hub.docker.com/r/xream/sub-store)）：

| 本模块配置变量 | 对应 Docker 环境变量 | 说明 |
| --- | --- | --- |
| `sub_store_backend_host` | `SUB_STORE_BACKEND_API_HOST` | 后端监听地址，局域网用 `0.0.0.0` |
| `sub_store_backend_port` | `SUB_STORE_BACKEND_API_PORT` | 后端端口（默认 3000） |
| `sub_store_frontend_host` / `_port` | `SUB_STORE_FRONTEND_HOST` / `SUB_STORE_FRONTEND_PORT` | 前端监听（默认 3001） |
| `sub_store_frontend_backend_path` | `SUB_STORE_FRONTEND_BACKEND_PATH` | 前端访问后端的路径前缀 |
| `sub_store_backend_merge` | `SUB_STORE_BACKEND_MERGE` | 前后端合并为单端口 |
| `sub_store_body_json_limit` | `SUB_STORE_BODY_JSON_LIMIT` | 请求 Body 限制（默认 1mb） |
| `sub_store_backend_push_service` | `SUB_STORE_PUSH_SERVICE` | 推送服务（Bark / Telegram / PushPlus / shoutrrr） |
| `sub_store_mmdb_country_path` / `_asn_path` | `SUB_STORE_MMDB_COUNTRY_PATH` / `SUB_STORE_MMDB_ASN_PATH` | MaxMind GeoLite2 数据库 |
| `sub_store_max_header_size` | `SUB_STORE_MAX_HEADER_SIZE` | 响应头大小限制（Headers Overflow 时调大） |
| `sub_store_cors_allowed_origins` | `SUB_STORE_CORS_ALLOWED_ORIGINS` | CORS 白名单 |
| `sub_store_backend_default_proxy` | `SUB_STORE_BACKEND_DEFAULT_PROXY` | 默认代理（SOCKS5/HTTP/HTTPS） |
| `sub_store_backend_custom_name` / `_icon` | `SUB_STORE_BACKEND_CUSTOM_NAME` / `SUB_STORE_BACKEND_CUSTOM_ICON` | 前端显示名称/图标 |
| `sub_store_x_powered_by` | `SUB_STORE_X_POWERED_BY` | 自定义 `X-Powered-By` 响应头 |
| `http_meta_host` / `http_meta_port` | `HOST` / `PORT` | HTTP-META 监听（默认 9876） |
| `http_meta_body_json_limit` | `BODY_JSON_LIMIT` | HTTP-META Body 限制 |
| `http_meta_disable_auto_clean` | `META_DISABLE_AUTO_CLEAN` | 调试：保留核心运行日志/配置 |
| `run_as_user` | - | 运行用户：`shell`(默认, uid 2000 低权限) / 置空=root |

## 手动操作

```sh
su -c "sh /data/adb/modules/sub_store/scripts/sub_store.service start"    # 启动
su -c "sh /data/adb/modules/sub_store/scripts/sub_store.service stop"     # 停止
su -c "sh /data/adb/modules/sub_store/scripts/sub_store.service restart"  # 重启
su -c "sh /data/adb/modules/sub_store/scripts/update_backend.sh"          # 更新后端
su -c "sh /data/adb/modules/sub_store/scripts/update_frontend.sh"         # 更新前端
su -c "sh /data/adb/modules/sub_store/scripts/update_http_meta.sh all"    # 更新 http-meta
```

> 在 `/data/adb/sub_store/manual` 创建空文件可禁止开机自启（手动控制）。

## 卸载

管理器删除模块即可：服务会自动停止，`/data/adb/sub_store` 数据保留（如需彻底删除请手动删除该目录）。

## 构建

### GitHub Actions（推荐）

- 手动触发：Actions → Build Sub-Store module → Run workflow，可选 ABI 与版本号
- 推送 `v*` tag：自动构建并发布 release
- 所有组件在线获取，无需本地参考文件；node 二进制来自 [node-android-build](https://github.com/Delusions6515/node-android-build) 的 release（先构建该仓库）

### 本地构建

```sh
./build.sh                    # 默认版本 (module.prop), arm64-v8a
./build.sh v2.1.0             # 指定版本
TARGET_ABI=armeabi-v7a ./build.sh v2.1.0   # 指定 ABI
NODE_BIN_PATH=~/node ./build.sh            # 本地 node 二进制 (调试用)
```

- 组件来源：
  - **node**：`NODE_REPO`（默认 `Delusions6515/node-android-build`）release 列表中
    `node-android-<arch>-*` 版本号最大者（该仓库默认构建全部 4 架构且保留历史版本）；
    可用 `NODE_DIST_URL` / `NODE_BIN_PATH` 覆盖
  - **后端**：`sub-store-org/Sub-Store` latest release
  - **前端**：`sub-store-org/Sub-Store-Front-End` latest release
  - **http-meta**：`xream/http-meta` latest release + `MetaCubeX/mihomo` 稳定版内核
- 构建产物默认输出到当前目录的 `build/` 下（可用 `OUT_DIR` 覆盖）
- 自动下载官方 `module_installer.sh` 生成 META-INF（恢复模式刷入用），失败时跳过（管理器安装不受影响）

## 目录结构

```
Sub-Store-Module/
├── .github/workflows/build.yml # GitHub Actions 构建 (手动/打 tag)
├── build.sh                  # 构建脚本 (在线获取全部组件)
├── module/
│   ├── module.prop           # 模块元数据
│   ├── customize.sh          # 安装脚本
│   ├── action.sh             # [执行] 按钮入口 (音量键菜单)
│   ├── service.sh            # 开机启动 (late_start service)
│   ├── uninstall.sh          # 卸载脚本
│   └── scripts/
│       ├── lib.sh            # 公共函数库
│       ├── sub_store.config  # 默认配置 (对应 Docker 环境变量)
│       ├── sub_store.service # 服务控制 start/stop/restart
│       ├── sub_store.inotify # 模块开关监控
│       ├── start.sh          # 开机启动入口
│       ├── update_backend.sh # 更新 Sub-Store 后端
│       ├── update_frontend.sh# 更新 Sub-Store 前端
│       └── update_http_meta.sh # 更新 http-meta (js/tpl/内核)
└── sub_store/bin/            # 内置二进制 (构建时从参考 zip 提取, 不入库)
```

## 许可

GPL-3.0。本模块脚本基于 xream 的 [Sub-Store for Magisk](https://github.com/xream/Sub-Store-for-Magisk) 重新开发；
Sub-Store / HTTP-META / mihomo 版权归其各自作者所有。
