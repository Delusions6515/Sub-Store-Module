#!/system/bin/sh
# ============================================================
# Sub-Store for Android - WebUI 脚本入口
# 用法:
#   webui.sh status|start|stop|restart|toggle-autostart|log|
#            read-env|save-env|
#            regenerate-backend-path|update-all|update-sub-store|
#            update-backend|update-frontend|update-http-meta [mode]
# 复用 sub_store.service 与各 update_*.sh, 不重复实现更新逻辑
# ============================================================

SCRIPTS_DIR=$(dirname "$0")
. "$SCRIPTS_DIR/lib.sh"
load_config

# 更新命令结束时写完成标记（退出码），供前端区分"更新真正结束"与"下载中途日志停滞"。
# 只在 UPDATE_DONE_MARKER=1（update-* 分支）时生效；$? 须先存起来，后续测试会覆盖它。
trap 'rc=$?; [ "${UPDATE_DONE_MARKER:-}" = "1" ] && echo "$rc" > "$run_path/update.done"' EXIT

CMD=${1:-}
MODE=${2:-all}

case "$CMD" in
  status)
    print_status_json
    ;;
  start)
    # 先轮转操作日志，再以追加模式调用 service（输出写入全新的 run.log）
    rotate_run_log
    sh "$SCRIPTS_DIR/sub_store.service" start >>"$run_path/run.log" 2>>"$run_path/run_error.log"
    ;;
  stop)
    rotate_run_log
    sh "$SCRIPTS_DIR/sub_store.service" stop >>"$run_path/run.log" 2>>"$run_path/run_error.log"
    ;;
  restart)
    rotate_run_log
    sh "$SCRIPTS_DIR/sub_store.service" restart >>"$run_path/run.log" 2>>"$run_path/run_error.log"
    ;;
  log-reset)
    # 归档当前 run.log/update.log 并清除完成标记，供前端在操作前同步轮转
    rotate_run_log
    rotate_update_log
    rm -f "$run_path/update.done"
    ;;
  log)
    # 输出 run.log / run_error.log 全部内容（配合 rotate_run_log，内容即最近一次操作输出）
    if [ -f "$run_path/run.log" ]; then
      tail -n 100 "$run_path/run.log"
    fi
    if [ -s "$run_path/run_error.log" ]; then
      echo "[Error] --- run_error.log ---"
      tail -n 50 "$run_path/run_error.log"
    fi
    ;;
  toggle-autostart)
    toggle_autostart
    ;;
  regenerate-backend-path)
    regenerate_backend_path
    ;;
  read-env)
    # 输出用户配置 env 内容（缺失时先从模块默认落一份），不碰模块内置文件
    ensure_user_env || exit 1
    cat "${sub_store_path}/scripts/sub_store.env"
    ;;
  save-env)
    # 入参: base64 编码的 env 内容；先落用户文件再备份，最后还原写入
    if [ -z "${2:-}" ]; then
      echo "[Error] 用法: webui.sh save-env <base64 内容>"
      exit 1
    fi
    ensure_user_env || exit 1
    backup_env_file || exit 1
    printf '%s' "$2" | base64 -d > "${sub_store_path}/scripts/sub_store.env" || {
      echo "[Error] 写入 env 文件失败: ${sub_store_path}/scripts/sub_store.env"
      exit 1
    }
    echo "[Info] 已保存 env 文件"
    ;;
  update-all)
    # 更新输出统一写入 update.log（配合 rotate_update_log 归档，前端可只读本次更新日志）；
    # 末尾重启的操作日志（run.log）追加进 update.log，方便确认重启结果
    UPDATE_DONE_MARKER=1
    rotate_update_log
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_backend.sh"       >>"$run_path/update.log" 2>>"$run_path/update_error.log" || exit 1
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_frontend.sh"      >>"$run_path/update.log" 2>>"$run_path/update_error.log" || exit 1
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_http_meta.sh" all >>"$run_path/update.log" 2>>"$run_path/update_error.log" || exit 1
    restart_service
    tail -n 50 "$run_path/run.log" >>"$run_path/update.log" 2>/dev/null
    ;;
  update-sub-store)
    UPDATE_DONE_MARKER=1
    rotate_update_log
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_backend.sh"  >>"$run_path/update.log" 2>>"$run_path/update_error.log" || exit 1
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_frontend.sh" >>"$run_path/update.log" 2>>"$run_path/update_error.log" || exit 1
    restart_service
    tail -n 50 "$run_path/run.log" >>"$run_path/update.log" 2>/dev/null
    ;;
  update-backend)
    UPDATE_DONE_MARKER=1
    rotate_update_log
    sh "$SCRIPTS_DIR/update_backend.sh" >>"$run_path/update.log" 2>>"$run_path/update_error.log"
    # 更新脚本内部可能重启服务，把重启操作日志（run.log）追加进更新日志
    tail -n 50 "$run_path/run.log" >>"$run_path/update.log" 2>/dev/null
    ;;
  update-frontend)
    UPDATE_DONE_MARKER=1
    rotate_update_log
    sh "$SCRIPTS_DIR/update_frontend.sh" >>"$run_path/update.log" 2>>"$run_path/update_error.log"
    tail -n 50 "$run_path/run.log" >>"$run_path/update.log" 2>/dev/null
    ;;
  update-http-meta)
    UPDATE_DONE_MARKER=1
    rotate_update_log
    sh "$SCRIPTS_DIR/update_http_meta.sh" "$MODE" >>"$run_path/update.log" 2>>"$run_path/update_error.log"
    tail -n 50 "$run_path/run.log" >>"$run_path/update.log" 2>/dev/null
    ;;
  log-size)
    # 输出 run.log 当前字节数，供前端轮询判断服务操作是否完成（日志停止增长即结束）
    wc -c < "$run_path/run.log" 2>/dev/null || echo 0
    ;;
  update-log)
    # 输出 update.log / update_error.log 全部内容（本次更新 + 重启操作日志）
    if [ -f "$run_path/update.log" ]; then
      tail -n 200 "$run_path/update.log"
    fi
    if [ -s "$run_path/update_error.log" ]; then
      echo "[Error] --- update_error.log ---"
      tail -n 50 "$run_path/update_error.log"
    fi
    ;;
  update-log-size)
    # 输出 update.log 当前字节数
    wc -c < "$run_path/update.log" 2>/dev/null || echo 0
    ;;
  update-status)
    # 更新完成状态：update.done 存在则输出退出码，否则输出 running。
    # 前端据此判断更新真正结束（大文件下载可能长时间不写日志，不能靠字节数判断完成）
    if [ -f "$run_path/update.done" ]; then
      cat "$run_path/update.done"
    else
      echo "running"
    fi
    ;;
  *)
    echo "用法: $0 {status|start|stop|restart|toggle-autostart|log|log-reset|log-size|update-log|update-log-size|update-status|read-env|save-env|regenerate-backend-path|update-all|update-sub-store|update-backend|update-frontend|update-http-meta [all|js|kernel|kernel-alpha]}"
    exit 1
    ;;
esac
