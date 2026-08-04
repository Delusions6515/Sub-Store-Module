#!/system/bin/sh
# ============================================================
# 更新 Sub-Store 后端 (sub-store.bundle.js)
# 设置 NO_RESTART=1 时跳过服务重启 (由调用方统一重启)
# ============================================================

SCRIPTS_DIR=$(dirname "$0")
. "$SCRIPTS_DIR/lib.sh"
load_config

BIN_DIR="$sub_store_path/bin"
URL="https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js"
TMP="$BIN_DIR/sub-store.bundle.js.new"

current=$(cat "$BIN_DIR/backend_version" 2>/dev/null || echo unknown)
info "Sub-Store 后端当前版本: $current"

rm -f "$TMP"
info "下载最新后端 ..."
if ! download "$URL" "$TMP"; then
  rm -f "$TMP"
  err "后端下载失败"
  exit 1
fi
[ -s "$TMP" ] || { rm -f "$TMP"; err "下载文件为空"; exit 1; }

new=$(sed -n 's/.*SUB_STORE_BACKEND_VERSION: //p' "$TMP" | head -n 1)
if [ -z "$new" ]; then
  rm -f "$TMP"
  err "无法识别版本号"
  exit 1
fi
info "Sub-Store 后端最新版本: $new"

if [ "$current" = "$new" ]; then
  rm -f "$TMP"
  info "已是最新版本, 无需更新"
  exit 0
fi

# 完整性检查 (正常 bundle 约 3MB)
size=$(wc -c < "$TMP")
if [ "$size" -lt 100000 ]; then
  rm -f "$TMP"
  err "下载文件异常 (大小: $size)"
  exit 1
fi

mv -f "$BIN_DIR/sub-store.bundle.js" "$BIN_DIR/sub-store.bundle.js.old" 2>/dev/null
mv -f "$TMP" "$BIN_DIR/sub-store.bundle.js"
echo "$new" > "$BIN_DIR/backend_version"
info "后端已更新到 $new"

if [ "$NO_RESTART" != "1" ]; then
  info "重启服务 ..."
  restart_service
fi
