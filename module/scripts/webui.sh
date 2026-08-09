#!/system/bin/sh
# ============================================================
# Sub-Store for Android - WebUI 脚本入口
# 用法:
#   webui.sh status|start|stop|restart|toggle-autostart|log|
#            regenerate-backend-path|update-all|update-sub-store|
#            update-backend|update-frontend|update-http-meta [mode]
# 复用 sub_store.service 与各 update_*.sh, 不重复实现更新逻辑
# ============================================================

SCRIPTS_DIR=$(dirname "$0")
. "$SCRIPTS_DIR/lib.sh"
load_config

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
    # 归档当前 run.log/update.log，供前端在操作前同步轮转，保证新日志只含本次输出
    rotate_run_log
    rotate_update_log
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
  update-all)
    # 更新输出统一写入 update.log（配合 rotate_update_log 归档，前端可只读本次更新日志）；
    # 末尾重启的操作日志（run.log）追加进 update.log，方便确认重启结果
    rotate_update_log
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_backend.sh"       >>"$run_path/update.log" 2>>"$run_path/update_error.log" || exit 1
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_frontend.sh"      >>"$run_path/update.log" 2>>"$run_path/update_error.log" || exit 1
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_http_meta.sh" all >>"$run_path/update.log" 2>>"$run_path/update_error.log" || exit 1
    restart_service
    tail -n 50 "$run_path/run.log" >>"$run_path/update.log" 2>/dev/null
    ;;
  update-sub-store)
    rotate_update_log
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_backend.sh"  >>"$run_path/update.log" 2>>"$run_path/update_error.log" || exit 1
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_frontend.sh" >>"$run_path/update.log" 2>>"$run_path/update_error.log" || exit 1
    restart_service
    tail -n 50 "$run_path/run.log" >>"$run_path/update.log" 2>/dev/null
    ;;
  update-backend)
    rotate_update_log
    sh "$SCRIPTS_DIR/update_backend.sh" >>"$run_path/update.log" 2>>"$run_path/update_error.log"
    # 更新脚本内部可能重启服务，把重启操作日志（run.log）追加进更新日志
    tail -n 50 "$run_path/run.log" >>"$run_path/update.log" 2>/dev/null
    ;;
  update-frontend)
    rotate_update_log
    sh "$SCRIPTS_DIR/update_frontend.sh" >>"$run_path/update.log" 2>>"$run_path/update_error.log"
    tail -n 50 "$run_path/run.log" >>"$run_path/update.log" 2>/dev/null
    ;;
  update-http-meta)
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
      tail -n 100 "$run_path/update.log"
    fi
    if [ -s "$run_path/update_error.log" ]; then
      echo "[Error] --- update_error.log ---"
      tail -n 50 "$run_path/update_error.log"
    fi
    ;;
  update-log-size)
    # 输出 update.log 当前字节数，供前端轮询判断更新是否完成
    wc -c < "$run_path/update.log" 2>/dev/null || echo 0
    ;;
  *)
    echo "用法: $0 {status|start|stop|restart|toggle-autostart|log|log-reset|log-size|update-log|update-log-size|regenerate-backend-path|update-all|update-sub-store|update-backend|update-frontend|update-http-meta [all|js|kernel|kernel-alpha]}"
    exit 1
    ;;
esac
