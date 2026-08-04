#!/system/bin/sh
# ============================================================
# 更新 Sub-Store 前端 (dist.zip)
# 设置 NO_RESTART=1 时跳过服务重启 (由调用方统一重启)
# ============================================================

SCRIPTS_DIR=$(dirname "$0")
. "$SCRIPTS_DIR/lib.sh"
load_config

BIN_DIR="$sub_store_path/bin"
URL="https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip"
TMP_ZIP="$BIN_DIR/frontend.new.zip"
TMP_DIR="$BIN_DIR/frontend.new"

current=$(cat "$BIN_DIR/frontend_version" 2>/dev/null || echo unknown)
info "Sub-Store 前端当前版本: $current"

rm -f "$TMP_ZIP"
rm -rf "$TMP_DIR"
info "下载最新前端 ..."
if ! download "$URL" "$TMP_ZIP"; then
  rm -f "$TMP_ZIP"
  err "前端下载失败"
  exit 1
fi
[ -s "$TMP_ZIP" ] || { rm -f "$TMP_ZIP"; err "下载文件为空"; exit 1; }

if ! unzip -q "$TMP_ZIP" -d "$TMP_DIR"; then
  rm -f "$TMP_ZIP"
  rm -rf "$TMP_DIR"
  err "解压失败"
  exit 1
fi
rm -f "$TMP_ZIP"

new=$(sed -n 's/.*<meta name="version" content="\([^"]*\)".*/\1/p' "$TMP_DIR/dist/index.html" 2>/dev/null | head -n 1)
if [ -z "$new" ]; then
  rm -rf "$TMP_DIR"
  err "无法识别版本号"
  exit 1
fi
info "Sub-Store 前端最新版本: $new"

if [ "$current" = "$new" ]; then
  rm -rf "$TMP_DIR"
  info "已是最新版本, 无需更新"
  exit 0
fi

# 原子替换
rm -rf "$BIN_DIR/frontend.old"
mv "$BIN_DIR/frontend" "$BIN_DIR/frontend.old" 2>/dev/null
mv "$TMP_DIR/dist" "$BIN_DIR/frontend"
rm -rf "$TMP_DIR"
echo "$new" > "$BIN_DIR/frontend_version"
info "前端已更新到 $new"

if [ "$NO_RESTART" != "1" ]; then
  info "重启服务 ..."
  restart_service
fi
