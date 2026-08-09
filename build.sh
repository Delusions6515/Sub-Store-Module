#!/bin/bash
# ============================================================
# Sub-Store for Android - 模块构建脚本
# 所有组件均从公开 release 在线获取, 无需本地参考文件,
# 可直接在 GitHub Actions 中运行。
#
# 用法:
#   ./build.sh                 # 版本名取最近 git tag (如 v1.0.0), 默认 arm64-v8a
#   ./build.sh 1.1.0           # 指定版本名覆盖 tag
#   ./build.sh 1.1.0 out.zip   # 指定版本名和输出路径
#
# 版本命名参考 ZygiskNext (module.prop 中为占位符, 不硬编码):
#   version=1.0.0 (<git提交数>-<短hash>-release)
#   versionCode=<git提交数>
#
# 环境变量:
#   TARGET_ABI       目标 ABI: arm64-v8a(默认)|armeabi-v7a|x86_64|x86
#   NODE_REPO        node 二进制来源仓库 (默认 Delusions6515/node-android-build,
#                    始终使用官方最新 LTS: 从该仓库 node-android-<arch>-<major> release
#                    取对应版本 tar.xz, 尚未构建时回退该大版本已有最高版本)
#   NODE_VERSION     指定内置 node 版本 (如 22.14.0; lts 或留空取官方最新 LTS)
#   NODE_DIST_URL    直接指定 node tar.xz 下载地址 (覆盖 NODE_REPO/NODE_VERSION)
#   NODE_BIN_PATH    直接指定本地 node 二进制文件 (覆盖上面所有, 本地调试用)
#   BUILD_TYPE       构建类型: release(默认)|hotfix|prerelease|canary
#   SKIP_VERSION_CHECK  设为 1 跳过新旧版本对比 (默认对比上游最新, 过旧自动刷新)
#   WEBUI_REPO_DIR   WebUI 源码仓库目录 (默认 ../Sub-Store-Module-WebUI)
#   WEBUI_DIST_DIR   直接指定已构建好的 WebUI dist 目录 (覆盖 WEBUI_REPO_DIR)
#   OUT_DIR          输出目录 (默认 ./build)
#
# 组件目录 $REPO_DIR/bin/ (结构同 sub_store/bin, 含版本文件):
#   构建时优先使用, 缺失或过旧的组件自动下载最新版到 bin/ (本地 / CI 缓存复用);
#   离线开发可用 SKIP_VERSION_CHECK=1 跳过对比, 直接用 bin/ 现状。
# ============================================================
set -euo pipefail

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
MODULE_DIR="$REPO_DIR/module"
WEBUI_REPO_DIR="${WEBUI_REPO_DIR:-$(cd "$REPO_DIR/.." && pwd)/Sub-Store-Module-WebUI}"
WEBUI_DIST_DIR="${WEBUI_DIST_DIR:-}"
OUT_DIR="${OUT_DIR:-$(pwd)/build}"
TARGET_ABI="${TARGET_ABI:-arm64-v8a}"
NODE_VERSION="${NODE_VERSION:-}"
VERSION="${1:-}"
OUT_ZIP="${2:-}"

info() { echo "[*] $1"; }
warn() { echo "[!] $1"; }
die()  { echo "[Error] $1"; exit 1; }

download() {  # $1=url $2=输出文件
  curl -fsSL --connect-timeout 10 --max-time 600 --retry 3 --retry-delay 2 --retry-max-time 60 "$1" -o "$2"
}

# ---------- ABI 映射 ----------
case "$TARGET_ABI" in
  arm64-v8a)   MIHOMO_ABI="arm64-v8"; NODE_ARCH="arm64" ;;
  armeabi-v7a) MIHOMO_ABI="armv7";    NODE_ARCH="arm" ;;
  x86_64)      MIHOMO_ABI="amd64";    NODE_ARCH="x64" ;;
  x86)         MIHOMO_ABI="386";      NODE_ARCH="ia32" ;;
  *) die "不支持的 TARGET_ABI: $TARGET_ABI (arm64-v8a|armeabi-v7a|x86_64|x86)" ;;
esac
info "目标 ABI: $TARGET_ABI (mihomo: $MIHOMO_ABI, node: $NODE_ARCH)"

# ---------- mihomo 稳定版 tag ----------
mihomo_stable_tag() {
  local tag
  tag=$(curl -fsSL --max-time 30 "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" \
    | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  if [ -z "$tag" ]; then
    tag=$(curl -sIL --max-time 30 "https://github.com/MetaCubeX/mihomo/releases/latest" \
      | sed -n 's/^[Ll]ocation: .*\/tag\/\(.*\)\r\?$/\1/p' | tail -n 1)
  fi
  # 去 CR/空白, 保证与版本文件精确比对一致
  tag=${tag//$'\r'/}
  echo "$tag"
}

# ---------- 上游最新版本 (新旧对比用; 失败返回空不中断) ----------
# 期望使用的 node 版本: 指定 NODE_VERSION 或官方最新 LTS
node_expected_version() {
  if [ -n "$NODE_VERSION" ] && [ "$NODE_VERSION" != "lts" ] && [ "$NODE_VERSION" != "latest" ]; then
    echo "${NODE_VERSION#v}"
  else
    curl -fsSL --max-time 30 "https://nodejs.org/dist/index.json" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
l = [x for x in d if x.get("lts")]
print(l[0]["version"].lstrip("v") if l else "")' || true
  fi
}

# 某 GitHub 仓库最新 release 的 tag
latest_github_tag() {  # $1=owner/repo
  curl -fsSL --max-time 30 "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 || true
}

# ---------- 组件下载 ----------
fetch_node() {  # $1 = sub_store/bin 目录
  local dest="$1" bin="$1/sub_store_node"
  if [ -n "${NODE_BIN_PATH:-}" ]; then
    info "node: 使用本地文件 $NODE_BIN_PATH"
    cp -f "$NODE_BIN_PATH" "$bin"
    return
  fi
  local url="" ver=""
  if [ -n "${NODE_DIST_URL:-}" ]; then
    url="$NODE_DIST_URL"
  else
    local repo="${NODE_REPO:-Delusions6515/node-android-build}"
    local lts_ver major rel
    lts_ver=$(node_expected_version)
    [ -n "$lts_ver" ] || die "无法解析 node 版本 (指定 NODE_VERSION 或官方最新 LTS)"
    major="${lts_ver%%.*}"
    info "node: $lts_ver, 从 $repo release node-android-${NODE_ARCH}-${major} 获取 ..."
    rel=$(curl -fsSL --max-time 30 "https://api.github.com/repos/$repo/releases/tags/node-android-${NODE_ARCH}-${major}" || true)
    # 优先取最新 LTS 版本对应的 asset; 尚未构建则回退该大版本已有最高版本
    url=$(echo "$rel" | grep -oE '"browser_download_url": "[^"]*node-android-'"${NODE_ARCH}"'-'"${lts_ver}"'\.tar\.xz"' \
      | head -n 1 | sed -E 's/.*"browser_download_url": "([^"]+)".*/\1/')
    if [ -z "$url" ]; then
      warn "node $lts_ver 尚未构建, 回退到 node-android-${NODE_ARCH}-${major} 中已有最高版本"
      url=$(echo "$rel" | grep -oE '"browser_download_url": "[^"]*node-android-'"${NODE_ARCH}"'-'"${major}"'\.[0-9]+\.[0-9]+\.tar\.xz"' \
        | head -n 1 | sed -E 's/.*"browser_download_url": "([^"]+)".*/\1/')
    fi
    [ -n "$url" ] || die "release node-android-${NODE_ARCH}-${major} 中未找到 node tar.xz 资产 (需要先构建 node-android-build 仓库)"
  fi
  ver=$(basename "$url" | sed -E 's/node-android-[a-z0-9]+-([0-9.]+)\.tar\.xz/\1/')
  info "node: 下载 $ver ($NODE_ARCH) ..."
  local tmp
  tmp=$(mktemp -d)
  download "$url" "$tmp/node.tar.xz"
  tar -xf "$tmp/node.tar.xz" -C "$tmp"
  cp -f "$tmp"/nodejs-*/bin/node "$bin"
  rm -rf "$tmp"
  echo "$ver" > "$dest/node_version"
}

fetch_backend() {  # $1 = sub_store/bin 目录
  local dest="$1" tmp="$1/sub-store.bundle.js.new"
  info "后端: 下载 Sub-Store bundle ..."
  download "https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js" "$tmp"
  local ver
  ver=$(sed -n 's/.*SUB_STORE_BACKEND_VERSION: //p' "$tmp" | head -n 1)
  [ -n "$ver" ] || die "无法识别后端版本号"
  mv -f "$tmp" "$dest/sub-store.bundle.js"
  echo "$ver" > "$dest/backend_version"
  info "后端: $ver"
}

fetch_frontend() {  # $1 = sub_store/bin 目录
  local dest="$1" tmp
  info "前端: 下载 dist.zip ..."
  tmp=$(mktemp -d)
  download "https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip" "$tmp/dist.zip"
  unzip -q "$tmp/dist.zip" -d "$tmp/x"
  local ver
  ver=$(sed -n 's/.*<meta name="version" content="\([^"]*\)".*/\1/p' "$tmp/x/dist/index.html" 2>/dev/null | head -n 1)
  [ -n "$ver" ] || die "无法识别前端版本号"
  rm -rf "$dest/frontend"
  mv "$tmp/x/dist" "$dest/frontend"
  rm -rf "$tmp"
  echo "$ver" > "$dest/frontend_version"
  info "前端: $ver"
}

fetch_http_meta() {  # $1 = sub_store/bin 目录
  local dest="$1" hm="$1/http-meta"
  mkdir -p "$hm"
  info "http-meta: 下载 bundle + tpl.yaml ..."
  download "https://github.com/xream/http-meta/releases/latest/download/http-meta.bundle.js" "$dest/http-meta.bundle.js"
  download "https://github.com/xream/http-meta/releases/latest/download/tpl.yaml" "$hm/tpl.yaml"
  local tag
  tag=$(mihomo_stable_tag)
  [ -n "$tag" ] || die "无法获取 mihomo 稳定版版本号"
  info "http-meta: 下载 mihomo 内核 $tag ($MIHOMO_ABI) ..."
  download "https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-android-${MIHOMO_ABI}-${tag}.gz" "$hm/http-meta.gz"
  gunzip -c "$hm/http-meta.gz" > "$hm/http-meta"
  rm -f "$hm/http-meta.gz"
  echo "$tag" > "$hm/kernel_version"
  info "http-meta: 内核 $tag"
}

# ---------- 新旧版本对比 (默认开启, SKIP_VERSION_CHECK=1 跳过) ----------
# 对比 bin/ 内组件版本与上游最新版, 过旧/缺失则自动重新下载刷新。
refresh_if_stale() {  # $1=版本文件 $2=组件名 $3=期望版本; 过旧/缺失返回 1 (触发刷新)
  local ver
  ver=$(cat "$1" 2>/dev/null || true)
  if [ -z "$3" ]; then
    warn "版本检查: 无法解析 $2 最新版本, 跳过"
    return 0
  fi
  if [ -z "$ver" ] || [ "$ver" != "$3" ]; then
    warn "版本检查: $2 过旧 (bin=${ver:-无}, 最新=$3), 自动刷新"
    return 1
  fi
  info "版本检查: $2 = $ver (最新)"
  return 0
}

check_components_fresh() {  # $1 = sub_store/bin 目录
  [ "${SKIP_VERSION_CHECK:-0}" = "1" ] && { info "版本检查: 跳过 (SKIP_VERSION_CHECK=1)"; return 0; }
  local dir="$1"
  info "版本检查: 对比上游最新版本 (过旧自动刷新) ..."
  refresh_if_stale "$dir/node_version" "node" "$(node_expected_version)" || fetch_node "$dir"
  refresh_if_stale "$dir/backend_version" "后端" "$(latest_github_tag "sub-store-org/Sub-Store")" || fetch_backend "$dir"
  refresh_if_stale "$dir/frontend_version" "前端" "$(latest_github_tag "sub-store-org/Sub-Store-Front-End")" || fetch_frontend "$dir"
  refresh_if_stale "$dir/http-meta/kernel_version" "mihomo" "$(mihomo_stable_tag)" || fetch_http_meta "$dir"
  info "版本检查: 完成"
}

# ---------- WebUI ----------
build_webui() {
  local dist="${WEBUI_DIST_DIR:-}"
  if [ -n "$dist" ]; then
    [ -d "$dist" ] || die "WEBUI_DIST_DIR 不存在: $dist"
  elif [ -f "$WEBUI_REPO_DIR/package.json" ]; then
    dist="$WEBUI_REPO_DIR/dist"
    info "WebUI: 构建 $WEBUI_REPO_DIR ..."
    command -v pnpm >/dev/null 2>&1 || die "未找到 pnpm, 无法构建 WebUI"
    (
      cd "$WEBUI_REPO_DIR"
      if [ -f pnpm-lock.yaml ]; then
        pnpm install --frozen-lockfile
      else
        pnpm install
      fi
      pnpm build
    )
  else
    info "WebUI: 未发现源码仓库, 跳过"
    return 0
  fi

  [ -f "$dist/index.html" ] || die "WebUI 构建产物缺少 index.html: $dist"
  rm -rf "$STAGE/webroot"
  mkdir -p "$STAGE/webroot"
  cp -r "$dist"/. "$STAGE/webroot/"
  info "WebUI: 已写入 module/webroot"
}

# ---------- 1. 拷贝模块源码 ----------
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -r "$MODULE_DIR/." "$STAGE/"
find "$STAGE" -name .DS_Store -delete

# ---------- 2. 组件 ----------
# 组件目录 $REPO_DIR/bin (结构同 sub_store/bin, 含版本文件); 构建优先使用,
# 缺失的组件自动下载补齐到 bin/ (本地 / CI 缓存复用)。
STAGE_BIN="$STAGE/sub_store/bin"
BIN_DIR="$REPO_DIR/bin"
mkdir -p "$STAGE_BIN" "$BIN_DIR"

# 逐项补齐缺失组件 (下载到 bin/ 持久化)
[ -e "$BIN_DIR/sub_store_node" ]      || fetch_node      "$BIN_DIR"
[ -e "$BIN_DIR/sub-store.bundle.js" ] || fetch_backend   "$BIN_DIR"
[ -e "$BIN_DIR/frontend/index.html" ] || fetch_frontend  "$BIN_DIR"
[ -e "$BIN_DIR/http-meta.bundle.js" ] || fetch_http_meta "$BIN_DIR"

# 新旧对比: 过旧组件自动刷新 (SKIP_VERSION_CHECK=1 跳过)
check_components_fresh "$BIN_DIR"

# 同步到 stage
cp -rf "$BIN_DIR/." "$STAGE_BIN/"

# 校验关键文件
for f in \
  sub_store/bin/sub_store_node \
  sub_store/bin/sub-store.bundle.js \
  sub_store/bin/http-meta.bundle.js \
  sub_store/bin/http-meta/http-meta \
  sub_store/bin/http-meta/tpl.yaml \
  sub_store/bin/frontend/index.html; do
  [ -e "$STAGE/$f" ] || die "缺少组件文件: $f"
done

# ---------- 3. WebUI ----------
build_webui

# ---------- 4. META-INF (官方 module_installer.sh), 失败则跳过 ----------
mkdir -p "$STAGE/META-INF/com/google/android"
if download "https://raw.githubusercontent.com/topjohnwu/Magisk/master/scripts/module_installer.sh" \
  "$STAGE/META-INF/com/google/android/update-binary"; then
  printf '#MAGISK\n' > "$STAGE/META-INF/com/google/android/updater-script"
  info "已获取官方 module_installer.sh (支持恢复模式刷入)"
else
  rm -rf "$STAGE/META-INF"
  warn "获取 module_installer.sh 失败, 跳过 META-INF (管理器内安装不受影响)"
fi

# ---------- 5. 版本 (参考 ZygiskNext: versionCode=git 提交数, version 附带短 hash) ----------
# 版本名: 优先参数/环境变量, 其次取最近 git tag (自动去 v 前缀), 最后回退 dev
VER_NAME="${VERSION:-}"
if [ -z "$VER_NAME" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  VER_NAME=$(git describe --tags --exact-match HEAD 2>/dev/null \
    || git describe --tags --abbrev=0 2>/dev/null || true)
fi
VER_NAME="${VER_NAME:-dev}"
VER_NAME="${VER_NAME#v}"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  VER_CODE=$(git rev-list HEAD --count 2>/dev/null || echo 1)
  VER_HASH=$(git rev-parse --verify --short HEAD 2>/dev/null || echo unknown)
else
  warn "不在 git 仓库中, versionCode 回退为 1"
  VER_CODE=1
  VER_HASH="nogit"
fi
BUILD_TYPE="${BUILD_TYPE:-release}"
VERSION_LINE="$VER_NAME ($VER_CODE-$VER_HASH-$BUILD_TYPE)"
sed -i "s/^version=.*/version=$VERSION_LINE/; s/^versionCode=.*/versionCode=$VER_CODE/" "$STAGE/module.prop"
info "版本: $VERSION_LINE (versionCode: $VER_CODE)"

# ---------- 6. updateJson (各架构分开, 由 workflow 发布到 gh-pages 分支) ----------
UPDATE_JSON_BASE="${UPDATE_JSON_BASE:-https://raw.githubusercontent.com/Delusions6515/Sub-Store-Module/gh-pages}"
sed -i "/^updateJson=/d" "$STAGE/module.prop"
echo "updateJson=$UPDATE_JSON_BASE/update-${TARGET_ABI}.json" >> "$STAGE/module.prop"
info "updateJson: $UPDATE_JSON_BASE/update-${TARGET_ABI}.json"

# ---------- 7. 权限 ----------
find "$STAGE" -type f \( -name '*.sh' -o -name 'sub_store.service' -o -name 'sub_store.inotify' -o -name 'update-binary' \) -exec chmod 755 {} +
find "$STAGE" -type d -exec chmod 755 {} +
chmod 755 "$STAGE/sub_store/bin/sub_store_node" "$STAGE/sub_store/bin/http-meta/http-meta"

# ---------- 8. 打包 ----------
mkdir -p "$OUT_DIR"
if [ -z "$OUT_ZIP" ]; then
  # 所有 ABI 统一带后缀 (与 workflow update JSON 的 zipUrl 命名对齐)
  OUT_ZIP="$OUT_DIR/sub-store-module-${VER_NAME}-${VER_CODE}-${VER_HASH}-${BUILD_TYPE}-${TARGET_ABI}.zip"
fi
rm -f "$OUT_ZIP"
(cd "$STAGE" && zip -rq "$OUT_ZIP" .)

echo
info "已生成: $OUT_ZIP"
info "内置组件版本:"
[ -f "$STAGE/sub_store/bin/node_version" ]             && echo "  node:      $(cat "$STAGE/sub_store/bin/node_version")"
[ -f "$STAGE/sub_store/bin/backend_version" ]          && echo "  后端:     $(cat "$STAGE/sub_store/bin/backend_version")"
[ -f "$STAGE/sub_store/bin/frontend_version" ]         && echo "  前端:     $(cat "$STAGE/sub_store/bin/frontend_version")"
[ -f "$STAGE/sub_store/bin/http-meta/kernel_version" ] && echo "  mihomo:   $(cat "$STAGE/sub_store/bin/http-meta/kernel_version")"
ls -lh "$OUT_ZIP"
