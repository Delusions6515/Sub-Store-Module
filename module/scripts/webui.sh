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
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_backend.sh"       || exit 1
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_frontend.sh"      || exit 1
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_http_meta.sh" all || exit 1
    restart_service
    ;;
  update-sub-store)
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_backend.sh"  || exit 1
    NO_RESTART=1 sh "$SCRIPTS_DIR/update_frontend.sh" || exit 1
    restart_service
    ;;
  update-backend)
    sh "$SCRIPTS_DIR/update_backend.sh"
    ;;
  update-frontend)
    sh "$SCRIPTS_DIR/update_frontend.sh"
    ;;
  update-http-meta)
    sh "$SCRIPTS_DIR/update_http_meta.sh" "$MODE"
    ;;
  *)
    echo "用法: $0 {status|start|stop|restart|toggle-autostart|log|regenerate-backend-path|update-all|update-sub-store|update-backend|update-frontend|update-http-meta [all|js|kernel|kernel-alpha]}"
    exit 1
    ;;
esac
