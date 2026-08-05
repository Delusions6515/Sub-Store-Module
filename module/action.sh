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

MODDIR=${0%/*}
SCRIPTS_DIR="$MODDIR/scripts"
. "$SCRIPTS_DIR/lib.sh"
load_config

GETEVENT=$(command -v getevent 2>/dev/null || echo /system/bin/getevent)
TIMEOUT_BIN=$(command -v timeout 2>/dev/null || echo "")

# 读取音量键: 0=VOL+ 1=VOL- 2=超时
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
      "")                    return 2 ;;
      *) : ;; # UP 等其它事件, 忽略并继续读取
    esac
  done
}

# ---------- 直达地址计算 (显示在 TUI 顶部 + 浏览器打开用) ----------
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
  # 非合并: 后端也带路径前缀 (SUB_STORE_FRONTEND_BACKEND_PATH 属后端配置)
  if [ -n "${SUB_STORE_FRONTEND_BACKEND_PATH:-}" ]; then
    BACK_ADDR="http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}${SUB_STORE_FRONTEND_BACKEND_PATH}"
    FRONT_ADDR="http://127.0.0.1:${SUB_STORE_FRONTEND_PORT:-3001}?api=http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}${SUB_STORE_FRONTEND_BACKEND_PATH}"
  else
    BACK_ADDR="http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}"
    FRONT_ADDR="http://127.0.0.1:${SUB_STORE_FRONTEND_PORT:-3001}"
  fi
fi
# 浏览器打开目标: 合并用单地址, 非合并打开前端
OPEN_URL="$FRONT_ADDR"

# 开机自启当前状态
if [ -f "$sub_store_path/manual" ]; then
  AUTOSTART_LABEL="启用开机自启 (当前: 已禁用)"
else
  AUTOSTART_LABEL="禁用开机自启 (当前: 已启用)"
fi

MENU_SEL=1

# 清屏: 优先 clear 命令 (无 ANSI 转义的环境也能用换行滚屏达到刷新效果)
clear_screen() {
  if command -v clear >/dev/null 2>&1; then
    clear
  else
    printf '\033[2J\033[H'
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
      *) : ;; # 其它输入事件, 忽略
    esac
  done
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

# ---------- 主菜单 ----------
pick \
  "请选择操作" \
  "浏览器打开直达地址" \
  "启动 Sub-Store" \
  "停止 Sub-Store" \
  "重启 Sub-Store" \
  "$AUTOSTART_LABEL" \
  "更新选项 ..."

case "$MENU_SEL" in
  1) open_address ;;
  2) sh "$SCRIPTS_DIR/sub_store.service" start ;;
  3) sh "$SCRIPTS_DIR/sub_store.service" stop ;;
  4) sh "$SCRIPTS_DIR/sub_store.service" restart ;;
  5) toggle_autostart ;;
  6)
    # ---------- 更新子菜单 ----------
    pick \
      "更新选项" \
      "全部更新 (Sub-Store 前后端 + http-meta)" \
      "更新 Sub-Store 前后端" \
      "仅更新 Sub-Store 后端" \
      "仅更新 Sub-Store 前端" \
      "更新 http-meta ..."
    case "$MENU_SEL" in
      1)
        echo "== 开始: 全部更新 =="
        NO_RESTART=1 sh "$SCRIPTS_DIR/update_backend.sh"    || exit 1
        NO_RESTART=1 sh "$SCRIPTS_DIR/update_frontend.sh"   || exit 1
        NO_RESTART=1 sh "$SCRIPTS_DIR/update_http_meta.sh" all || exit 1
        restart_service
        echo "== 全部更新完成 =="
        ;;
      2)
        echo "== 开始: 更新 Sub-Store 前后端 =="
        NO_RESTART=1 sh "$SCRIPTS_DIR/update_backend.sh"  || exit 1
        NO_RESTART=1 sh "$SCRIPTS_DIR/update_frontend.sh" || exit 1
        restart_service
        echo "== 前后端更新完成 =="
        ;;
      3)
        sh "$SCRIPTS_DIR/update_backend.sh" || exit 1
        ;;
      4)
        sh "$SCRIPTS_DIR/update_frontend.sh" || exit 1
        ;;
      5)
        # ---------- http-meta 子菜单 ----------
        pick \
          "更新 http-meta" \
          "[默认] 全部更新 (js + tpl.yaml + mihomo 内核)" \
          "只更新 http-meta (js + tpl.yaml)" \
          "只更新 mihomo 内核 (稳定版)" \
          "只更新 mihomo 内核 (Prerelease-Alpha 预览版)"
        case "$MENU_SEL" in
          1) sh "$SCRIPTS_DIR/update_http_meta.sh" all          || exit 1 ;;
          2) sh "$SCRIPTS_DIR/update_http_meta.sh" js           || exit 1 ;;
          3) sh "$SCRIPTS_DIR/update_http_meta.sh" kernel       || exit 1 ;;
          4) sh "$SCRIPTS_DIR/update_http_meta.sh" kernel-alpha || exit 1 ;;
        esac
        ;;
    esac
    ;;
esac

echo ""
echo "完成。"
