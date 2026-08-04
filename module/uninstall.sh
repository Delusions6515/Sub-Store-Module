#!/system/bin/sh
# ============================================================
# Sub-Store for Android - 卸载脚本
# 停止服务并移除监控; /data/adb/sub_store 数据默认保留
# ============================================================

MODDIR=${0%/*}
SCRIPTS_DIR="$MODDIR/scripts"

# 停止 inotifyd 监控
for pid in $(pidof inotifyd 2>/dev/null); do
  grep -q sub_store.inotify /proc/$pid/cmdline 2>/dev/null && kill "$pid" 2>/dev/null
done

# 停止服务
if [ -f "$SCRIPTS_DIR/sub_store.service" ]; then
  sh "$SCRIPTS_DIR/sub_store.service" stop >/dev/null 2>&1
fi
kill -15 $(pidof sub_store_node http-meta) 2>/dev/null
sleep 1
kill -9 $(pidof sub_store_node http-meta) 2>/dev/null

echo "- Sub-Store 服务已停止"
echo "- 数据保留在 /data/adb/sub_store (如需彻底删除请手动删除)"
