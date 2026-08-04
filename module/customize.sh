#!/sbin/sh
# ============================================================
# Sub-Store for Android - 安装脚本
# 由 Magisk / KernelSU 安装器在解压并设置默认权限后 source
# 参考:
#   https://topjohnwu.github.io/Magisk/guides.html
#   https://kernelsu.org/guide/module.html
# ============================================================

ui_print "*******************************"
ui_print "  Sub-Store for Android"
ui_print "  by Delusions6515"
ui_print "*******************************"

# 仅支持在管理器内安装 (需要 root 初始化 /data/adb/sub_store)
if [ "$BOOTMODE" != "true" ]; then
  abort "! 请使用 Magisk/KernelSU 管理器安装本模块"
fi

# KernelSU 最低版本要求 (模块脚本 / action.sh 支持)
if [ "$KSU" = "true" ] && [ "${KSU_VER_CODE:-0}" -lt 10670 ]; then
  abort "! 请升级 KernelSU 后再安装 (需要 >= 10670)"
fi

DATA_DIR=/data/adb/sub_store
BIN_DIR=$DATA_DIR/bin
SCRIPTS_DIR=$DATA_DIR/scripts
RUN_DIR=$DATA_DIR/run

ui_print "- 初始化运行时目录 $DATA_DIR"
mkdir -p "$BIN_DIR" "$SCRIPTS_DIR" "$RUN_DIR"

# 内置二进制: 仅在全新安装时拷贝
# 升级时保留 /data/adb/sub_store/bin 中已被 [执行] 按钮更新过的版本
if [ ! -f "$BIN_DIR/sub_store_node" ]; then
  ui_print "- 首次安装: 拷贝内置二进制"
  cp -rf "$MODPATH/sub_store/bin/." "$BIN_DIR/"
else
  ui_print "- 检测到已有运行时数据, 保留现有二进制"
  ui_print "- 组件更新请使用管理器内的 [执行] 按钮"
fi
rm -rf "$MODPATH/sub_store"

# 配置文件: 保留用户已有配置
if [ ! -f "$SCRIPTS_DIR/sub_store.config" ]; then
  ui_print "- 写入默认配置文件 sub_store.config"
  cp -f "$MODPATH/scripts/sub_store.config" "$SCRIPTS_DIR/sub_store.config"
fi

# 清理旧版 (xream v1) 遗留的开机脚本, 避免与新模块的 service.sh 重复启动
rm -f /data/adb/service.d/sub_store_service.sh
rm -f /data/adb/ksu/service.d/sub_store_service.sh

# 清理旧版遗留的 inotifyd 监控进程
for pid in $(pidof inotifyd 2>/dev/null); do
  grep -q sub_store.inotify /proc/$pid/cmdline 2>/dev/null && kill "$pid" 2>/dev/null
done

# 权限
set_perm_recursive "$MODPATH" 0 0 0755 0644
# 二进制目录: 文件 0644/可执行 0755, root 所有; shell 用户可读可执行
set_perm_recursive "$BIN_DIR" 0 0 0755 0644
chmod 755 "$BIN_DIR/sub_store_node" "$BIN_DIR/http-meta/http-meta" 2>/dev/null
# 低权限运行 (默认 shell uid 2000): 运行目录与 http-meta 目录授权给该用户
# (mihomo 需要写 geoip 数据库, node 需要写日志/数据)
chown -R 2000:2000 "$RUN_DIR" "$BIN_DIR/http-meta" 2>/dev/null || true
# 配置文件含推送 token 等敏感信息, root 专属
set_perm "$SCRIPTS_DIR/sub_store.config" 0 0 0600
chmod ugo+x "$MODPATH"/*.sh "$MODPATH"/scripts/*.sh 2>/dev/null

ui_print "- 安装完成"
ui_print "- 重启后 Sub-Store 将自动启动 (低权限 shell 用户运行):"
ui_print "  http://127.0.0.1:3001  (后端 :3000, HTTP-META :9876)"
ui_print "- 管理器内点击 [执行] 可按音量键选择更新"
