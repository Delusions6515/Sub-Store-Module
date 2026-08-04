#!/system/bin/sh
# ============================================================
# Sub-Store for Android - 公共函数库
# 被模块内其它脚本 source, 不单独执行
# 注意: 运行环境为 busybox ash, 勿使用 bash 数组等特性
# ============================================================

# ---------- 配置加载 ----------
# 优先使用用户配置 (/data/adb/sub_store/scripts/sub_store.config)
# 否则使用模块内置默认配置
load_config() {
  CONFIG_FILE=/data/adb/sub_store/scripts/sub_store.config
  if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="$SCRIPTS_DIR/sub_store.config"
  fi
  # shellcheck disable=SC1090
  . "$CONFIG_FILE" 2>/dev/null || {
    echo "[Error] 配置文件加载失败: $CONFIG_FILE"
    exit 1
  }
}

# ---------- 输出 ----------
info() { echo "[Info] $1"; }
warn() { echo "[Warn] $1"; }
err()  { echo "[Error] $1"; }

# ---------- 下载: curl 优先, 回退 wget ----------
download() {  # $1=url  $2=输出文件路径
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 10 --max-time 600 --retry 3 --retry-delay 2 --retry-max-time 60 "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    err "未找到 curl / wget, 无法下载"
    return 127
  fi
}

# ---------- 抓取文本 (版本号 / API) ----------
fetch_text() {  # $1=url
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 10 --max-time 30 "$1" 2>/dev/null
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1" 2>/dev/null
  fi
}

# ---------- 服务控制 ----------
restart_service() { "$SCRIPTS_DIR/sub_store.service" restart; }
stop_service()     { "$SCRIPTS_DIR/sub_store.service" stop; }
