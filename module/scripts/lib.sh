#!/system/bin/sh
# ============================================================
# Sub-Store for Android - 公共函数库
# 被模块内其它脚本 source, 不单独执行
# 注意: 运行环境为 busybox ash, 勿使用 bash 数组等特性
# ============================================================

# ---------- 配置加载 ----------
# 优先使用用户配置 (/data/adb/sub_store/scripts/), 否则使用模块内置默认配置
# sub_store.config 仅含模块特有配置; sub_store.env 为服务环境变量 (Docker 版一致)
load_config() {
  CONFIG_DIR=/data/adb/sub_store/scripts
  if [ -d "$CONFIG_DIR" ]; then
    CONFIG_FILE="$CONFIG_DIR/sub_store.config"
    ENV_FILE="$CONFIG_DIR/sub_store.env"
  else
    CONFIG_FILE="$SCRIPTS_DIR/sub_store.config"
    ENV_FILE="$SCRIPTS_DIR/sub_store.env"
  fi
  # shellcheck disable=SC1090
  . "$CONFIG_FILE" 2>/dev/null || {
    echo "[Error] 配置文件加载失败: $CONFIG_FILE"
    exit 1
  }
  # 环境变量文件缺失时回退模块内置默认 (升级前旧配置无此文件)
  # ENV_SOURCE 记录实际加载的文件, 供服务脚本导入全部变量
  ENV_SOURCE="$ENV_FILE"
  [ -f "$ENV_SOURCE" ] || ENV_SOURCE="$SCRIPTS_DIR/sub_store.env"
  [ -f "$ENV_SOURCE" ] && . "$ENV_SOURCE" 2>/dev/null

  # 配置修改提醒: 用户改了配置但服务未重启时, 提示手动重启 (服务启动流程跳过)
  if [ "${SERVICE_STARTING:-}" != "1" ] && [ -d "$CONFIG_DIR" ] \
    && [ -n "${run_path:-}" ] && [ -f "$run_path/.start_marker" ]; then
    if [ "$CONFIG_FILE" -nt "$run_path/.start_marker" ] \
      || [ "$ENV_SOURCE" -nt "$run_path/.start_marker" ]; then
      warn "检测到配置已修改, 但服务未重启, 当前运行的是旧配置"
      warn "请执行: su -c \"sh /data/adb/modules/sub_store/scripts/sub_store.service restart\""
    fi
  fi
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
