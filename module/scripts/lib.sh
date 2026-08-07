#!/system/bin/sh
# ============================================================
# Sub-Store for Android - 公共函数库
# 被模块内其它脚本 source, 不单独执行
# 注意: 运行环境为 busybox ash, 勿使用 bash 数组等特性
# ============================================================

# ---------- 配置加载 ----------
# 优先使用用户配置 (/data/local/sub_store/scripts/), 否则使用模块内置默认配置
# sub_store.config 仅含模块特有配置; sub_store.env 为服务环境变量 (Docker 版一致)
load_config() {
  CONFIG_DIR=/data/local/sub_store/scripts
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
}

# 配置是否在启动后被修改 (返回 0=已修改未重启, 1=正常/不适用)
# 供 load_config 输出提醒, 也供 TUI (action.sh) 菜单顶部常驻显示
# 服务未运行时视为正常: 配置会在下次启动时生效, 不存在"旧配置在跑"的问题
# (开机启动时序中服务可能尚未拉起, 不加此判断会误报)
config_modified() {
  pidof "$bin_name" >/dev/null 2>&1 || return 1
  if [ "${SERVICE_STARTING:-}" != "1" ] && [ -d "$CONFIG_DIR" ] \
    && [ -n "${run_path:-}" ] && [ -f "$run_path/.start_marker" ]; then
    [ "$CONFIG_FILE" -nt "$run_path/.start_marker" ] \
      || [ "$ENV_SOURCE" -nt "$run_path/.start_marker" ]
  else
    return 1
  fi
}

# ---------- SUB_STORE_FRONTEND_BACKEND_PATH ----------
# 模块内置默认值 (与 sub_store.env 保持一致, 改默认值时两处都要改)
# 首次安装时会被随机替换; 若检测到仍在使用该默认值, TUI (action.sh) 会告警
DEFAULT_BACKEND_PATH="/2cXaAxRGfddmGz2yx1wA"

# 生成随机 SUB_STORE_FRONTEND_BACKEND_PATH: / + 20~24 位随机字符 (a-zA-Z0-9)
# 成功输出新路径; 失败输出空 (调用方自行处理)
# 不使用 local (兼容安装器环境), 内部变量统一 _bp_ 前缀避免污染
# 注意: 部分 sh 环境 (dash) 无 $RANDOM, 算术里按空值处理, len 退化为 20
gen_backend_path() {
  _bp_len=$((20 + (RANDOM % 5)))
  _bp_out=""
  # 首选 /dev/urandom; tr 过滤非字母数字, head 取前 N 位 (urandom 不 EOF, 必然取满)
  _bp_out=$(tr -dc 'a-zA-Z0-9' </dev/urandom 2>/dev/null | head -c "$_bp_len" 2>/dev/null)
  if [ "$(printf '%s' "$_bp_out" | wc -c)" -ne "$_bp_len" ]; then
    # 回退: 用 $RANDOM 逐字符生成 (busybox ash / mksh 支持)
    _bp_out=""
    _bp_chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    _bp_i=0
    while [ "$_bp_i" -lt "$_bp_len" ]; do
      _bp_idx=$(( (RANDOM % 62) + 1 ))
      _bp_out="$_bp_out$(printf '%s' "$_bp_chars" | cut -c "$_bp_idx")"
      _bp_i=$((_bp_i + 1))
    done
  fi
  if [ "$(printf '%s' "$_bp_out" | wc -c)" -eq "$_bp_len" ]; then
    printf '/%s' "$_bp_out"
  fi
}

# ---------- 状态 / 地址 ----------
service_running() {
  pidof "$bin_name" >/dev/null 2>&1
}

autostart_enabled() {
  [ ! -f "$sub_store_path/manual" ]
}

backend_path_is_default() {
  [ "${SUB_STORE_FRONTEND_BACKEND_PATH:-}" = "$DEFAULT_BACKEND_PATH" ]
}

compute_direct_urls() {
  if [ "${SUB_STORE_BACKEND_MERGE:-}" = "true" ]; then
    # 合并模式: 单端口, 前端带 ?api= 指向后端路径
    if [ -n "${SUB_STORE_FRONTEND_BACKEND_PATH:-}" ]; then
      DIRECT_ADDR="http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}?api=http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}${SUB_STORE_FRONTEND_BACKEND_PATH}"
    else
      DIRECT_ADDR="http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}"
    fi
    FRONT_ADDR="$DIRECT_ADDR"
    BACK_ADDR="$DIRECT_ADDR"
  else
    # 非合并: 与官方 Docker 一致 — 前端 ?api= 指向前端端口+前缀 (前端代理转发到后端),
    # 后端入口地址同官方文档: 前端端口+前缀 (后端不直接暴露, 走前端代理)
    if [ -n "${SUB_STORE_FRONTEND_BACKEND_PATH:-}" ]; then
      BACK_ADDR="http://127.0.0.1:${SUB_STORE_FRONTEND_PORT:-3001}${SUB_STORE_FRONTEND_BACKEND_PATH}"
      FRONT_ADDR="http://127.0.0.1:${SUB_STORE_FRONTEND_PORT:-3001}?api=http://127.0.0.1:${SUB_STORE_FRONTEND_PORT:-3001}${SUB_STORE_FRONTEND_BACKEND_PATH}"
    else
      BACK_ADDR="http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}"
      FRONT_ADDR="http://127.0.0.1:${SUB_STORE_FRONTEND_PORT:-3001}"
    fi
  fi
  # 浏览器打开目标: 合并用单地址, 非合并打开前端
  OPEN_URL="$FRONT_ADDR"
}

# ---------- JSON 输出 ----------
json_escape() {
  printf '%s' "$1" | awk 'BEGIN { ORS="" }
    {
      gsub(/\\/, "\\\\")
      gsub(/"/, "\\\"")
      gsub(/\r/, "\\r")
      gsub(/\n/, "\\n")
      print
    }'
}

print_status_json() {
  load_config
  compute_direct_urls

  if service_running; then
    _service_running=true
  else
    _service_running=false
  fi

  if autostart_enabled; then
    _autostart=true
  else
    _autostart=false
  fi

  if config_modified; then
    _config_modified=true
  else
    _config_modified=false
  fi

  if [ "${SUB_STORE_BACKEND_MERGE:-}" = "true" ]; then
    _merge_mode=true
  else
    _merge_mode=false
  fi

  if backend_path_is_default; then
    _backend_path_is_default=true
  else
    _backend_path_is_default=false
  fi

  printf '{'
  printf '"serviceRunning":%s,' "$_service_running"
  printf '"autostart":%s,' "$_autostart"
  printf '"configModified":%s,' "$_config_modified"
  printf '"mergeMode":%s,' "$_merge_mode"
  printf '"directUrl":"%s",' "$(json_escape "$DIRECT_ADDR")"
  printf '"frontUrl":"%s",' "$(json_escape "$FRONT_ADDR")"
  printf '"backUrl":"%s",' "$(json_escape "$BACK_ADDR")"
  printf '"openUrl":"%s",' "$(json_escape "$OPEN_URL")"
  printf '"backendPathIsDefault":%s' "$_backend_path_is_default"
  printf '}\n'
}

# ---------- 动作 ----------
toggle_autostart() {
  if autostart_enabled; then
    touch "$sub_store_path/manual"
    echo "已禁用开机自启 (下次重启不再自动启动, 可手动执行启动)"
  else
    rm -f "$sub_store_path/manual"
    echo "已启用开机自启 (下次重启自动启动)"
  fi
}

# 写入用户实际生效的 env 文件 (/data/local/sub_store/scripts/sub_store.env);
# 老环境没有用户 env 时先落一份默认配置再替换, 避免改到会被模块更新覆盖的内置文件
regenerate_backend_path() {
  load_config
  local target="$CONFIG_DIR/sub_store.env"
  if [ ! -f "$target" ]; then
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    cp -f "$SCRIPTS_DIR/sub_store.env" "$target" 2>/dev/null || {
      err "无法创建 $target"
      return 1
    }
  fi
  local new_path
  new_path=$(gen_backend_path)
  if [ -z "$new_path" ]; then
    err "生成随机路径失败"
    return 1
  fi
  sed -i "s|^SUB_STORE_FRONTEND_BACKEND_PATH=.*|SUB_STORE_FRONTEND_BACKEND_PATH=\"$new_path\"|" "$target"
  echo "已生成新的 SUB_STORE_FRONTEND_BACKEND_PATH:"
  echo "  $new_path"
  echo "已写入: $target"
  echo "自动重启 Sub-Store 以应用新路径 ..."
  restart_service
  echo "重启完成"
}

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

# ---------- 输出 ----------
info() { echo "[Info] $1"; }
warn() { echo "[Warn] $1"; }
err()  { echo "[Error] $1"; }

# ---------- 服务控制 ----------
restart_service() { sh "$SCRIPTS_DIR/sub_store.service" restart; }
stop_service()     { sh "$SCRIPTS_DIR/sub_store.service" stop; }
