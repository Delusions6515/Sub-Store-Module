#!/system/bin/sh
# ============================================================
# Sub-Store for Android - 开机启动脚本 (late_start service 模式)
# 系统启动完成后启动 Sub-Store / HTTP-META
# 并监控模块目录, 禁用/启用模块时自动停止/启动服务
# ============================================================

MODDIR=${0%/*}
SCRIPTS_DIR="$MODDIR/scripts"

# 等待系统启动完成后再拉起服务
(
  until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 3
  done
  "$SCRIPTS_DIR/start.sh"
) &

# 监控模块目录: 创建 disable 文件(禁用模块)时停止服务, 删除时重启
inotifyd "$SCRIPTS_DIR/sub_store.inotify" "$MODDIR" >/dev/null 2>&1 &
