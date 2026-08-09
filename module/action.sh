#!/system/bin/sh
# ============================================================
# Sub-Store for Android - 执行菜单
# 在 KernelSU / Magisk / APatch 管理器内点击模块的 [执行] 按钮时运行
# (Magisk 需要 27008+, APatch 需要 11039+, KernelSU 需要 10670+)
#
# 操作方式 (与常见模块一致):
#   音量下键  移动到下一个选项
#   音量上键  确认当前选项
#   5 分钟无按键自动退出
# ============================================================

# ---------- 环境初始化 ----------
MODDIR=${0%/*}
SCRIPTS_DIR="$MODDIR/scripts"
. "$SCRIPTS_DIR/lib.sh"

GETEVENT=$(command -v getevent 2>/dev/null || echo /system/bin/getevent)
TIMEOUT_BIN=$(command -v timeout 2>/dev/null || echo "")

# ============================================================
# 低层 UI 辅助
# ============================================================

# 读取音量键: 0=VOL+ 1=VOL- 2=超时 3=BACK(退出)
# 内部消费 UP 等无关事件, 避免一次按键导致菜单重复刷新
read_vol() {
  local line=""
  while :; do
    if [ -n "$TIMEOUT_BIN" ]; then
      line=$("$TIMEOUT_BIN" 5 "$GETEVENT" -qlc 1 2>/dev/null)
    else
      line=$("$GETEVENT" -qlc 1 2>/dev/null)
    fi
    case "$line" in
      *KEY_VOLUMEUP*DOWN*)   return 0 ;;
      *KEY_VOLUMEDOWN*DOWN*) return 1 ;;
      *KEY_BACK*DOWN*)       return 3 ;;
      "")                    return 2 ;;
      *) : ;; # UP 等其它事件, 忽略并继续读取
    esac
  done
}

# 清屏: 优先 clear 命令 (无 clear 的环境也能用换行滚屏达到刷新效果)
# Magisk 管理器终端不支持 ANSI 转义 (clear 会输出 \033[H\033[J 原文)
clear_screen() {
  if [ "${APATCH:-}" = "true" -o "${KSU:-}" = "true" ]; then
    if command -v clear >/dev/null 2>&1; then
      clear
    fi
  else
    echo ""
  fi
}

# 绘制菜单: 每次循环全量重绘 (参考 funbox 模块实现)
draw_menu() {
  local title=$1
  shift
  local i=1
  clear_screen
  echo "***************************************"
  echo "  Sub-Store for Android - 执行菜单"
  echo "  音量下键 移动   音量上键 确认"
  echo "***************************************"
  echo ""
  if [ "${SUB_STORE_BACKEND_MERGE:-}" = "true" ]; then
    echo "  直达: $DIRECT_ADDR"
  else
    echo "  前端: $FRONT_ADDR"
    echo "  后端: $BACK_ADDR"
  fi
  # 配置修改提醒: 配置在启动后被改过且未重启, 常驻显示在菜单顶部
  if config_modified; then
    echo "  [!] 配置已修改但未重启, 当前运行的是旧配置"
    echo "      重启 Sub-Store 后生效"
  fi
  # 安全提醒: SUB_STORE_FRONTEND_BACKEND_PATH 仍为模块默认值时告警
  # (默认值所有安装者都一样, 等同公开路径, 建议随机化)
  if [ "${SUB_STORE_FRONTEND_BACKEND_PATH:-}" = "$DEFAULT_BACKEND_PATH" ]; then
    echo "  [!] SUB_STORE_FRONTEND_BACKEND_PATH 仍为模块默认值"
    echo "      建议用下方菜单项重新生成随机路径"
  fi
  # 安全提醒: 运行用户为 root 时告警
  if run_user_is_root; then
    echo "  [!] 当前运行用户为 root, 建议改为 shell 用户"
    echo "      可在 sub_store.config 中修改 run_as_user"
    echo "  shell 用户如果网络访问受限，可在 sub_store.env 中配置代理"
    echo '  SUB_STORE_BACKEND_DEFAULT_PROXY="<你的代理软件的代理地址>"'
  fi
  echo "---------------------------------------"
  echo ""
  echo "  --- $title ---"
  for opt in "$@"; do
    if [ "$i" -eq "$MENU_SEL" ]; then
      echo "-> $opt"
    else
      echo "  $opt"
    fi
    i=$((i + 1))
  done
  echo ""
  echo "***************************************"
}

# 交互选择: $1=标题, 其余=选项; 选择结果写入 MENU_SEL (1 起)
pick() {
  local title=$1
  shift
  MENU_SEL=1
  local max=$#
  local idle=0
  while true; do
    draw_menu "$title" "$@"
    sleep 0.3
    read_vol
    case $? in
      1) # 音量下键: 移动到下一个选项
        MENU_SEL=$((MENU_SEL + 1))
        [ "$MENU_SEL" -gt "$max" ] && MENU_SEL=1
        idle=0
        ;;
      0) # 音量上键: 确认
        echo ""
        return 0
        ;;
      2) # 超时
        idle=$((idle + 1))
        if [ "$idle" -ge 60 ]; then
          echo ""
          echo "[超时] 5 分钟未检测到按键, 已退出"
          exit 0
        fi
        ;;
      3) # 管理器返回键
        echo ""
        echo "已退出"
        exit 0
        ;;
      *) : ;; # 其它输入事件, 忽略
    esac
  done
}

# ============================================================
# 状态初始化
# ============================================================

# 直达地址计算 (显示在 TUI 顶部 + 浏览器打开用)
direct_addr() {
  load_config
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

# 开机自启当前状态 (manual 文件存在 = 不自动启动)
# 切换开关后要重新调用, 主菜单才能显示最新状态
autostart_status() {
  if [ -f "$sub_store_path/manual" ]; then
    AUTOSTART_LABEL="启用开机自启 (当前: 已禁用)"
  else
    AUTOSTART_LABEL="禁用开机自启 (当前: 已启用)"
  fi
}

# ============================================================
# 具体动作
# ============================================================

# ---------- 后台执行操作, TUI 实时显示 run.log (nohup 后台 + 日志轮转) ----------
# $1=标题, 其余为命令及参数; 后台运行并把输出写进 run.log, 边跑边显示, 结束返回命令退出码。
# 操作日志统一进 run.log: TUI 与 WebUI 都能看到本次操作输出。
run_op() {
  local title=$1
  shift
  rotate_run_log
  : >"$run_path/run.log"
  : >"$run_path/run_error.log"
  echo ""
  echo "== 开始: $title =="
  nohup "$@" >>"$run_path/run.log" 2>>"$run_path/run_error.log" &
  local pid=$!
  local offset=0 size
  # 轮询 run.log 新增长度并输出
  while kill -0 "$pid" 2>/dev/null; do
    size=$(wc -c <"$run_path/run.log" 2>/dev/null || echo 0)
    if [ "$size" -gt "$offset" ]; then
      tail -c +"$((offset + 1))" "$run_path/run.log" 2>/dev/null
      offset=$size
    fi
    sleep 1
  done
  wait "$pid"
  local rc=$?
  size=$(wc -c <"$run_path/run.log" 2>/dev/null || echo 0)
  if [ "$size" -gt "$offset" ]; then
    tail -c +"$((offset + 1))" "$run_path/run.log" 2>/dev/null
  fi
  if [ -s "$run_path/run_error.log" ]; then
    echo ""
    echo "[Error] --- run_error.log ---"
    tail -n 50 "$run_path/run_error.log"
  fi
  echo ""
  echo "== $title 结束 (退出码 $rc) =="
  return $rc
}

# ---------- 浏览器打开直达地址 (默认浏览器) ----------
open_address() {
  echo ""
  echo "正在打开: $OPEN_URL"
  if ! am start -a android.intent.action.VIEW -d "$OPEN_URL" >/dev/null 2>&1; then
    echo "[Error] 打开失败, 请手动在浏览器访问:"
    echo "  $OPEN_URL"
  fi
}

# ---------- 开机自启开关 (manual 文件存在 = 不自动启动) ----------
toggle_autostart() {
  if [ -f "$sub_store_path/manual" ]; then
    rm -f "$sub_store_path/manual"
    echo ""
    echo "已启用开机自启 (下次重启自动启动)"
  else
    touch "$sub_store_path/manual"
    echo ""
    echo "已禁用开机自启 (下次重启不再自动启动, 可手动执行启动)"
  fi
}

# ---------- 生成并替换 SUB_STORE_FRONTEND_BACKEND_PATH (随机化) ----------
# 写入用户实际生效的 env 文件 (/data/local/sub_store/scripts/sub_store.env);
# 老环境没有用户 env 时先落一份默认配置再替换, 避免改到会被模块更新覆盖的内置文件
regenerate_backend_path() {
  load_config
  local target="$CONFIG_DIR/sub_store.env"
  if [ ! -f "$target" ]; then
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    cp -f "$SCRIPTS_DIR/sub_store.env" "$target" 2>/dev/null || {
      echo ""
      echo "[Error] 无法创建 $target"
      return 1
    }
  fi
  local new_path
  new_path=$(gen_backend_path)
  if [ -z "$new_path" ]; then
    echo ""
    echo "[Error] 生成随机路径失败"
    return 1
  fi
  sed -i "s|^SUB_STORE_FRONTEND_BACKEND_PATH=.*|SUB_STORE_FRONTEND_BACKEND_PATH=\"$new_path\"|" "$target"
  echo ""
  echo "已生成新的 SUB_STORE_FRONTEND_BACKEND_PATH:"
  echo "  $new_path"
  echo "已写入: $target"
  echo "自动重启 Sub-Store 以应用新路径 ..."
  restart_service
  echo "重启完成"
}

# ============================================================
# 子菜单与主菜单
# ============================================================

# ---------- http-meta 子菜单 (返回上一级回到更新菜单) ----------
http_meta_menu() {
  while true; do
    pick \
      "更新 http-meta" \
      "[默认] 全部更新 (js + tpl.yaml + mihomo 内核)" \
      "只更新 http-meta (js + tpl.yaml)" \
      "只更新 mihomo 内核 (稳定版)" \
      "只更新 mihomo 内核 (Prerelease-Alpha 预览版)" \
      "返回上一级"
    case "$MENU_SEL" in
      1) run_op "http-meta 全部更新" sh "$SCRIPTS_DIR/update_http_meta.sh" all          || exit 1 ;;
      2) run_op "http-meta js + tpl" sh "$SCRIPTS_DIR/update_http_meta.sh" js           || exit 1 ;;
      3) run_op "http-meta 内核稳定版" sh "$SCRIPTS_DIR/update_http_meta.sh" kernel       || exit 1 ;;
      4) run_op "http-meta 内核 Alpha" sh "$SCRIPTS_DIR/update_http_meta.sh" kernel-alpha || exit 1 ;;
      5) return ;;
    esac
  done
}

# ---------- 更新子菜单 (返回上一级回到主菜单) ----------
update_menu() {
  while true; do
    pick \
      "更新选项" \
      "全部更新 (Sub-Store 前后端 + http-meta)" \
      "更新 Sub-Store 前后端" \
      "仅更新 Sub-Store 后端" \
      "仅更新 Sub-Store 前端" \
      "更新 http-meta ..." \
      "返回上一级"
    case "$MENU_SEL" in
      1) run_op "全部更新" sh -c "NO_RESTART=1 sh $SCRIPTS_DIR/update_backend.sh || exit 1; NO_RESTART=1 sh $SCRIPTS_DIR/update_frontend.sh || exit 1; NO_RESTART=1 sh $SCRIPTS_DIR/update_http_meta.sh all || exit 1; sh $SCRIPTS_DIR/sub_store.service restart; :" || exit 1 ;;
      2) run_op "更新 Sub-Store 前后端" sh -c "NO_RESTART=1 sh $SCRIPTS_DIR/update_backend.sh || exit 1; NO_RESTART=1 sh $SCRIPTS_DIR/update_frontend.sh || exit 1; sh $SCRIPTS_DIR/sub_store.service restart; :" || exit 1 ;;
      3) run_op "仅更新 Sub-Store 后端" sh "$SCRIPTS_DIR/update_backend.sh" || exit 1 ;;
      4) run_op "仅更新 Sub-Store 前端" sh "$SCRIPTS_DIR/update_frontend.sh" || exit 1 ;;
      5) http_meta_menu ;;
      6) return ;;
    esac
  done
}

# ---------- 主菜单 (循环, 退出选项结束) ----------
main_menu() {
  while true; do
    direct_addr
    autostart_status
    pick \
      "请选择操作" \
      "浏览器打开直达地址" \
      "启动 Sub-Store" \
      "停止 Sub-Store" \
      "重启 Sub-Store" \
      "生成并替换 SUB_STORE_FRONTEND_BACKEND_PATH" \
      "$AUTOSTART_LABEL" \
      "更新选项 ..." \
      "退出"
    case "$MENU_SEL" in
      1) open_address ;;
      2) sh "$SCRIPTS_DIR/sub_store.service" start   >>"$run_path/run.log" 2>>"$run_path/run_error.log" ;;
      3) sh "$SCRIPTS_DIR/sub_store.service" stop    >>"$run_path/run.log" 2>>"$run_path/run_error.log" ;;
      4) sh "$SCRIPTS_DIR/sub_store.service" restart >>"$run_path/run.log" 2>>"$run_path/run_error.log" ;;
      5) regenerate_backend_path ;;
      6) toggle_autostart ;;
      7) update_menu ;;
      8) break ;;
    esac
  done
}

# ============================================================
# 启动入口: 先计算直达地址 / 初始化自启状态, 再进主菜单
# ============================================================
main_menu

echo ""
echo "完成。"
