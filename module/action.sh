#!/system/bin/sh
# ============================================================
# Sub-Store for Android - 执行菜单
# 在 KernelSU / Magisk / APatch 管理器内点击模块的 [执行] 按钮时运行
# (Magisk 需要 27008+, APatch 需要 11039+, KernelSU 需要 10670+)
#
# 操作方式:
#   VOL+  切换到下一个选项
#   VOL-  确认当前选项
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

MENU_SEL=0

# 渲染完整界面 (清屏 + 标题横幅 + 菜单), 每次按键全量重绘, 实现真正 TUI 效果
render() {
  local title=$1
  shift
  local i=0
  printf '\033[2J\033[H'
  echo "=============================================="
  echo "  Sub-Store for Android - 执行菜单"
  echo "  VOL+ 下一个选项    VOL- 确认选择"
  echo "=============================================="
  echo ""
  echo "  --- $title ---"
  for opt in "$@"; do
    if [ "$i" = "$MENU_SEL" ]; then
      echo "  > $opt"
    else
      echo "    $opt"
    fi
    i=$((i + 1))
  done
}

# 交互选择: $1=标题, 其余=选项; 选择结果写入 MENU_SEL
pick() {
  local title=$1
  shift
  MENU_SEL=0
  local max=$(( $# - 1 ))
  local idle=0
  while true; do
    render "$title" "$@"
    read_vol
    case $? in
      0) # VOL+ 下一个
        MENU_SEL=$((MENU_SEL + 1))
        [ "$MENU_SEL" -gt "$max" ] && MENU_SEL=0
        idle=0
        ;;
      1) # VOL- 确认
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

# ---------- 查看后端/前端地址 (本机直连地址) ----------
show_addresses() {
  echo ""
  if [ "${SUB_STORE_BACKEND_MERGE:-}" = "true" ]; then
    # 合并模式: 单端口, 前端需带 ?api= 指向后端路径 (SUB_STORE_FRONTEND_BACKEND_PATH)
    if [ -n "${SUB_STORE_FRONTEND_BACKEND_PATH:-}" ]; then
      echo "http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}?api=http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}${SUB_STORE_FRONTEND_BACKEND_PATH}"
    else
      echo "http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}"
    fi
  else
    # 非合并: 后端也带路径前缀 (SUB_STORE_FRONTEND_BACKEND_PATH 属后端配置)
    if [ -n "${SUB_STORE_FRONTEND_BACKEND_PATH:-}" ]; then
      echo "后端: http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}${SUB_STORE_FRONTEND_BACKEND_PATH}"
      echo "前端: http://127.0.0.1:${SUB_STORE_FRONTEND_PORT:-3001}?api=http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}${SUB_STORE_FRONTEND_BACKEND_PATH}"
    else
      echo "后端: http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3000}"
      echo "前端: http://127.0.0.1:${SUB_STORE_FRONTEND_PORT:-3001}"
    fi
  fi
  echo ""
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

echo "=============================================="
echo "  Sub-Store for Android - 执行菜单"
echo "  VOL+ 下一个选项    VOL- 确认选择"
echo "=============================================="

# 开机自启当前状态
if [ -f "$sub_store_path/manual" ]; then
  AUTOSTART_LABEL="启用开机自启 (当前: 已禁用)"
else
  AUTOSTART_LABEL="禁用开机自启 (当前: 已启用)"
fi

# ---------- 主菜单 ----------
pick \
  "请选择操作" \
  "查看后端/前端地址" \
  "启动 Sub-Store" \
  "停止 Sub-Store" \
  "重启 Sub-Store" \
  "$AUTOSTART_LABEL" \
  "更新选项 ..."

case "$MENU_SEL" in
  0) show_addresses ;;
  1) "$SCRIPTS_DIR/sub_store.service" start ;;
  2) "$SCRIPTS_DIR/sub_store.service" stop ;;
  3) "$SCRIPTS_DIR/sub_store.service" restart ;;
  4) toggle_autostart ;;
  5)
    # ---------- 更新子菜单 ----------
    pick \
      "更新选项" \
      "全部更新 (Sub-Store 前后端 + http-meta)" \
      "更新 Sub-Store 前后端" \
      "仅更新 Sub-Store 后端" \
      "仅更新 Sub-Store 前端" \
      "更新 http-meta ..."
    case "$MENU_SEL" in
      0)
        echo "== 开始: 全部更新 =="
        NO_RESTART=1 "$SCRIPTS_DIR/update_backend.sh"    || exit 1
        NO_RESTART=1 "$SCRIPTS_DIR/update_frontend.sh"   || exit 1
        NO_RESTART=1 "$SCRIPTS_DIR/update_http_meta.sh" all || exit 1
        restart_service
        echo "== 全部更新完成 =="
        ;;
      1)
        echo "== 开始: 更新 Sub-Store 前后端 =="
        NO_RESTART=1 "$SCRIPTS_DIR/update_backend.sh"  || exit 1
        NO_RESTART=1 "$SCRIPTS_DIR/update_frontend.sh" || exit 1
        restart_service
        echo "== 前后端更新完成 =="
        ;;
      2)
        "$SCRIPTS_DIR/update_backend.sh" || exit 1
        ;;
      3)
        "$SCRIPTS_DIR/update_frontend.sh" || exit 1
        ;;
      4)
        # ---------- http-meta 子菜单 ----------
        pick \
          "更新 http-meta" \
          "[默认] 全部更新 (js + tpl.yaml + mihomo 内核)" \
          "只更新 http-meta (js + tpl.yaml)" \
          "只更新 mihomo 内核 (稳定版)" \
          "只更新 mihomo 内核 (Prerelease-Alpha 预览版)"
        case "$MENU_SEL" in
          0) "$SCRIPTS_DIR/update_http_meta.sh" all          || exit 1 ;;
          1) "$SCRIPTS_DIR/update_http_meta.sh" js           || exit 1 ;;
          2) "$SCRIPTS_DIR/update_http_meta.sh" kernel       || exit 1 ;;
          3) "$SCRIPTS_DIR/update_http_meta.sh" kernel-alpha || exit 1 ;;
        esac
        ;;
    esac
    ;;
esac

echo ""
echo "完成。"
