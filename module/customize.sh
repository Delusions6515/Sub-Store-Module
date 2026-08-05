#!/sbin/sh
# ============================================================
# Sub-Store for Android - 安装脚本
# 由 Magisk / KernelSU / APatch (APM) 安装器在解压并设置默认权限后 source
# 参考:
#   https://topjohnwu.github.io/Magisk/guides.html
#   https://kernelsu.org/guide/module.html
#   https://apatch.dev/apm-guide.html
# ============================================================

ui_print "*******************************"
ui_print "  Sub-Store for Android"
ui_print "  by Delusions6515"
ui_print "*******************************"

# 仅支持在管理器内安装 (需要 root 初始化数据目录)
if [ "$BOOTMODE" != "true" ]; then
  abort "! 请使用 Magisk/KernelSU 管理器安装本模块"
fi

# 执行按钮 (action.sh) 最低管理器版本要求:
#   Magisk >= 27008 (canary 27008 首次加入 action.sh 支持)
#   KernelSU >= 10670
#   APatch >= 11039 (首次加入 action.sh 支持)
if [ "${APATCH:-}" = "true" ]; then
  if [ "${APATCH_VER_CODE:-0}" -lt 11039 ]; then
    abort "! 请升级 APatch 后再安装 (执行按钮需要 APatch >= 11039)"
  fi
elif [ "${KSU:-}" = "true" ]; then
  if [ "${KSU_VER_CODE:-0}" -lt 10670 ]; then
    abort "! 请升级 KernelSU 后再安装 (执行按钮需要 >= 10670)"
  fi
else
  if [ "${MAGISK_VER_CODE:-0}" -lt 27008 ]; then
    abort "! 请升级 Magisk 后再安装 (执行按钮需要 Magisk >= 27008)"
  fi
fi

DATA_DIR=/data/local/sub_store
BIN_DIR=$DATA_DIR/bin
SCRIPTS_DIR=$DATA_DIR/scripts
RUN_DIR=$DATA_DIR/run

ui_print "- 初始化运行时目录 $DATA_DIR"
mkdir -p "$BIN_DIR" "$SCRIPTS_DIR" "$RUN_DIR"
# 数据目录归属 shell (uid 2000), 700 权限: App 无法进入, 不暴露 root
chmod 0700 "$DATA_DIR" 2>/dev/null || true
chown 2000:2000 "$DATA_DIR" 2>/dev/null || true

# 音量键交互: 检测到已有二进制时询问是否用包内新版本覆盖
# 0=音量+ 覆盖  1=音量-/超时 跳过
GETEVENT=$(command -v getevent 2>/dev/null || echo /system/bin/getevent)
TIMEOUT_BIN=$(command -v timeout 2>/dev/null || echo "")

ask_cover_bin() {
  ui_print "- 音量+ 覆盖 / 其他键 跳过 (5 秒无按键自动跳过)"
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
      "")                    return 1 ;;
      *) : ;; # UP 等无关事件, 忽略并继续读取
    esac
  done
}

# 内置二进制: 全新安装直接拷贝; 升级时询问是否覆盖
if [ ! -f "$BIN_DIR/sub_store_node" ]; then
  ui_print "- 首次安装: 拷贝内置二进制"
  cp -rf "$MODPATH/sub_store/bin/." "$BIN_DIR/"
else
  ui_print "- 检测到已有二进制"
  if ask_cover_bin; then
    ui_print "- 已选择覆盖: 用包内二进制覆盖现有版本"
    cp -rf "$MODPATH/sub_store/bin/." "$BIN_DIR/"
  else
    ui_print "- 已选择跳过: 保留现有二进制"
    ui_print "- 组件更新请使用管理器内的 [执行] 按钮"
  fi
fi
rm -rf "$MODPATH/sub_store"

# 配置文件: 保留用户已有配置
if [ ! -f "$SCRIPTS_DIR/sub_store.config" ]; then
  ui_print "- 写入默认配置文件 sub_store.config"
  cp -f "$MODPATH/scripts/sub_store.config" "$SCRIPTS_DIR/sub_store.config"
fi
if [ ! -f "$SCRIPTS_DIR/sub_store.env" ]; then
  ui_print "- 写入默认环境变量文件 sub_store.env"
  cp -f "$MODPATH/scripts/sub_store.env" "$SCRIPTS_DIR/sub_store.env"
fi

# 清理旧版 (xream v1) 遗留的开机脚本, 避免与新模块的 service.sh 重复启动
rm -f /data/adb/service.d/sub_store_service.sh
rm -f /data/adb/ksu/service.d/sub_store_service.sh

# 清理旧版遗留的 inotifyd 监控进程
for pid in $(pidof inotifyd 2>/dev/null); do
  grep -q sub_store.inotify /proc/$pid/cmdline 2>/dev/null && kill "$pid" 2>/dev/null
done

# 权限
set_perm_recursive "$MODPATH" 0 0 0755 0644
# 二进制目录: 文件 0644/可执行 0755, root 所有; shell 用户可读可执行
set_perm_recursive "$BIN_DIR" 0 0 0755 0644
chmod 755 "$BIN_DIR/sub_store_node" "$BIN_DIR/http-meta/http-meta" 2>/dev/null
# 低权限运行 (默认 shell uid 2000): 数据目录归属 shell; 运行目录与 http-meta 目录授权写
# (mihomo 需要写 geoip 数据库, node 需要写日志/数据)
chown -R 2000:2000 "$RUN_DIR" "$BIN_DIR/http-meta" 2>/dev/null || true
# 配置文件含推送 token 等敏感信息, root 专属
set_perm "$SCRIPTS_DIR/sub_store.config" 0 0 0600
set_perm "$SCRIPTS_DIR/sub_store.env" 0 0 0600
chmod ugo+x "$MODPATH"/*.sh "$MODPATH"/scripts/*.sh "$MODPATH"/scripts/sub_store.service "$MODPATH"/scripts/sub_store.inotify 2>/dev/null

ui_print "- 安装完成"
ui_print "- 重启后 Sub-Store 将自动启动 (低权限 shell 用户运行):"
ui_print "  http://127.0.0.1:3000  (默认合并端口, HTTP-META :9876)"
ui_print "- 管理器内点击 [执行] 可按音量键选择更新"
