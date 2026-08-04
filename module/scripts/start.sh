#!/system/bin/sh
# ============================================================
# 开机启动入口: 由 service.sh 在 sys.boot_completed 后调用
# 也可手动执行以立即启动服务
# ============================================================

SCRIPTS_DIR=$(dirname "$0")
. "$SCRIPTS_DIR/lib.sh"
load_config

# 等待用户解锁 (sdcard 可写), 部分功能需要访问 /sdcard
wait_until_login() {
  local test_file="/sdcard/Android/.sub_storeTEST"
  true > "$test_file"
  while [ ! -f "$test_file" ]; do
    true > "$test_file"
    sleep 1
  done
  rm -f "$test_file"
}
wait_until_login

# 模块被禁用时不启动
MODDIR=$(dirname "$SCRIPTS_DIR")
[ -f "$MODDIR/disable" ] && exit 0

rm -f "$pid_file" "$http_meta_pid_file" 2>/dev/null
mkdir -p "$run_path"

# 存在 manual 文件时跳过自动启动
if [ ! -f "$sub_store_path/manual" ]; then
  mv "$run_path/run.log" "$run_path/run.log.bak" >/dev/null 2>&1
  mv "$run_path/run_error.log" "$run_path/run_error.log.bak" >/dev/null 2>&1
  "$SCRIPTS_DIR/sub_store.service" restart >>"$run_path/run.log" 2>>"$run_path/run_error.log"
fi
