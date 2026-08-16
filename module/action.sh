#!/system/bin/sh
# ============================================================
# Sub-Store for Android - 执行菜单
# 在 KernelSU / Magisk / APatch 管理器内点击模块的 [执行] 按钮时运行
# (Magisk 需要 27008+, APatch 需要 11039+, KernelSU 需要 10670+)
#
# 操作方式 (与常见模块一致):
#   音量下键  移动到下一个选项
#   音量上键  确认当前选项
#   20 秒无按键自动退出
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

# 读取音量键: 0=VOL+ 1=VOL- 2=超时 3=物理 BACK(退出)
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
  echo "  请使用菜单退出；管理器返回键不会终止脚本"
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
  if backend_path_is_default; then
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
  local redraw=1
  while true; do
    # 只在按键后重绘, 超时静默等待 (Magisk 用滚屏清屏, 超时重绘会每几秒自动滚动)
    if [ "$redraw" -eq 1 ]; then
      draw_menu "$title" "$@"
      redraw=0
    fi
    sleep 0.3
    read_vol
    case $? in
      1) # 音量下键: 移动到下一个选项
        MENU_SEL=$((MENU_SEL + 1))
        [ "$MENU_SEL" -gt "$max" ] && MENU_SEL=1
        idle=0
        redraw=1
        ;;
      0) # 音量上键: 确认
        echo ""
        return 0
        ;;
      2) # 超时
        idle=$((idle + 1))
        if [ "$idle" -ge 4 ]; then
          echo ""
          echo "[超时] 20 秒未检测到按键, 已退出"
          exit 0
        fi
        ;;
      3) # 输入设备上报的物理 BACK 键
        echo ""
        echo "已退出"
        exit 0
        ;;
      *) : ;; # 其它输入事件, 忽略
    esac
  done
}

# ---------- 单实例: 新 action 终止本模块上一次 action ----------
stop_action_instance() {
  local owner_pid
  if [ -f "$ACTION_PID_FILE" ] && read -r owner_pid _ <"$ACTION_PID_FILE" \
    && [ "$owner_pid" = "$$" ]; then
    rm -f "$ACTION_PID_FILE"
  fi
}

start_action_instance() {
  ACTION_PID_FILE="$run_path/action.pid"
  local old_pid old_start current_start
  if [ -f "$ACTION_PID_FILE" ] && read -r old_pid old_start <"$ACTION_PID_FILE" \
    && [ -n "$old_pid" ] && [ -n "$old_start" ]; then
    current_start=$(awk '{print $22}' "/proc/$old_pid/stat" 2>/dev/null)
    if [ "$current_start" = "$old_start" ]; then
      kill "$old_pid" 2>/dev/null
      echo "[提示] 已终止本模块上一次执行菜单"
    fi
  fi

  mkdir -p "$run_path"
  echo "$$ $(awk '{print $22}' /proc/$$/stat 2>/dev/null)" >"$ACTION_PID_FILE"
  trap 'exit 0' HUP INT TERM
  trap stop_action_instance EXIT
}

# ============================================================
# 状态初始化
# ============================================================

# 开机自启当前状态 (manual 文件存在 = 不自动启动)
# 切换开关后要重新调用, 主菜单才能显示最新状态
autostart_status() {
  if autostart_enabled; then
    AUTOSTART_LABEL="禁用开机自启 (当前: 已启用)"
  else
    AUTOSTART_LABEL="启用开机自启 (当前: 已禁用)"
  fi
}

# ============================================================
# 具体动作
# ============================================================

# ---------- 后台执行操作, TUI 实时显示日志 (nohup 后台 + 日志轮转) ----------
# $1=标题, $2=日志名 (update=更新 / run=服务操作), 其余为命令及参数;
# 后台运行并把输出写进 ${logname}.log, 边跑边显示, 结束返回命令退出码。
# 与 webui.sh 一致: 更新输出统一进 update.log, 服务操作进 run.log,
# TUI 与 WebUI 看到同一份日志; 更新末尾把 run.log 追加进 update.log。
run_op() {
  local title=$1
  local logname=$2
  shift 2
  local log="$run_path/$logname.log"
  local errlog="$run_path/${logname}_error.log"
  rotate_run_log
  [ "$logname" = "update" ] && rotate_update_log
  : >"$log"
  : >"$errlog"
  echo ""
  echo "== 开始: $title =="
  nohup "$@" >>"$log" 2>>"$errlog" &
  local pid=$!
  local offset=0 size
  # 轮询日志新增长度并输出
  while kill -0 "$pid" 2>/dev/null; do
    size=$(wc -c <"$log" 2>/dev/null || echo 0)
    if [ "$size" -gt "$offset" ]; then
      tail -c +"$((offset + 1))" "$log" 2>/dev/null
      offset=$size
    fi
    sleep 1
  done
  wait "$pid"
  local rc=$?
  size=$(wc -c <"$log" 2>/dev/null || echo 0)
  if [ "$size" -gt "$offset" ]; then
    tail -c +"$((offset + 1))" "$log" 2>/dev/null
  fi
  # 更新: 重启操作日志（run.log）追加进 update.log 并显示; 服务操作日志即 run.log, 无需追加
  if [ "$logname" = "update" ]; then
    tail -n 50 "$run_path/run.log" 2>/dev/null | tee -a "$run_path/update.log"
  fi
  if [ -s "$errlog" ]; then
    echo ""
    echo "[Error] --- ${logname}_error.log ---"
    tail -n 50 "$errlog"
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
      1) run_op "http-meta 全部更新" update sh "$SCRIPTS_DIR/update_http_meta.sh" all          || exit 1 ;;
      2) run_op "http-meta js + tpl" update sh "$SCRIPTS_DIR/update_http_meta.sh" js           || exit 1 ;;
      3) run_op "http-meta 内核稳定版" update sh "$SCRIPTS_DIR/update_http_meta.sh" kernel       || exit 1 ;;
      4) run_op "http-meta 内核 Alpha" update sh "$SCRIPTS_DIR/update_http_meta.sh" kernel-alpha || exit 1 ;;
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
      1) run_op "全部更新" update sh -c "NO_RESTART=1 sh $SCRIPTS_DIR/update_backend.sh || exit 1; NO_RESTART=1 sh $SCRIPTS_DIR/update_frontend.sh || exit 1; NO_RESTART=1 sh $SCRIPTS_DIR/update_http_meta.sh all || exit 1; sh $SCRIPTS_DIR/sub_store.service restart; :" || exit 1 ;;
      2) run_op "更新 Sub-Store 前后端" update sh -c "NO_RESTART=1 sh $SCRIPTS_DIR/update_backend.sh || exit 1; NO_RESTART=1 sh $SCRIPTS_DIR/update_frontend.sh || exit 1; sh $SCRIPTS_DIR/sub_store.service restart; :" || exit 1 ;;
      3) run_op "仅更新 Sub-Store 后端" update sh "$SCRIPTS_DIR/update_backend.sh" || exit 1 ;;
      4) run_op "仅更新 Sub-Store 前端" update sh "$SCRIPTS_DIR/update_frontend.sh" || exit 1 ;;
      5) http_meta_menu ;;
      6) return ;;
    esac
  done
}

# ---------- 主菜单 (循环, 退出选项结束) ----------
main_menu() {
  while true; do
    load_config
    compute_direct_urls
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
      2) run_op "启动 Sub-Store" run sh "$SCRIPTS_DIR/sub_store.service" start ;;
      3) run_op "停止 Sub-Store" run sh "$SCRIPTS_DIR/sub_store.service" stop ;;
      4) run_op "重启 Sub-Store" run sh "$SCRIPTS_DIR/sub_store.service" restart ;;
      5) echo ""; regenerate_backend_path ;;
      6) echo ""; toggle_autostart ;;
      7) update_menu ;;
      8) break ;;
    esac
  done
}

# ============================================================
# 启动入口: 加载配置并登记单实例, 再进主菜单
# ============================================================
load_config
start_action_instance
main_menu

echo ""
echo "完成。"
