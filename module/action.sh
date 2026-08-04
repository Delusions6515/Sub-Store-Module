#!/system/bin/sh
# ============================================================
# Sub-Store for Android - 执行菜单
# 在 KernelSU / Magisk 管理器内点击模块的 [执行] 按钮时运行
#
# 操作方式:
#   VOL+  切换到下一个选项
#   VOL-  确认当前选项
#   5 分钟无按键自动退出
# ============================================================

MODDIR=${0%/*}
SCRIPTS_DIR="$MODDIR/scripts"
. "$SCRIPTS_DIR/lib.sh"

GETEVENT=$(command -v getevent 2>/dev/null || echo /system/bin/getevent)
TIMEOUT_BIN=$(command -v timeout 2>/dev/null || echo "")

# 读取一次音量键: 0=VOL+ 1=VOL- 2=超时 3=其它事件(忽略)
read_vol() {
  local line=""
  if [ -n "$TIMEOUT_BIN" ]; then
    line=$("$TIMEOUT_BIN" 5 "$GETEVENT" -qlc 1 2>/dev/null)
  else
    line=$("$GETEVENT" -qlc 1 2>/dev/null)
  fi
  case "$line" in
    *KEY_VOLUMEUP*DOWN*)   return 0 ;;
    *KEY_VOLUMEDOWN*DOWN*) return 1 ;;
    "")                    return 2 ;;
    *)                     return 3 ;;
  esac
}

MENU_SEL=0

# 显示菜单: $1=标题, 其余=选项, 高亮 MENU_SEL
show_menu() {
  local title=$1
  shift
  local i=0
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
    show_menu "$title" "$@"
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

echo "=============================================="
echo "  Sub-Store for Android - 执行菜单"
echo "  VOL+ 下一个选项    VOL- 确认选择"
echo "=============================================="

# ---------- 主菜单 ----------
pick \
  "请选择操作" \
  "全部更新 (Sub-Store 前后端 + http-meta)" \
  "更新 Sub-Store 前后端" \
  "仅更新 Sub-Store 后端" \
  "仅更新 Sub-Store 前端" \
  "更新 http-meta"

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

echo ""
echo "完成。"
