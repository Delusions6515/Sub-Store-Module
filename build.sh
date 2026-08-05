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
#                    取该仓库 node-android-<arch> release 中的 node-android-<arch>-*.tar.xz)
#   NODE_DIST_URL    直接指定 node tar.xz 下载地址 (覆盖 NODE_REPO)
#   NODE_BIN_PATH    直接指定本地 node 二进制文件 (覆盖上面两者, 本地调试用)
#   OUT_DIR          输出目录 (默认 ./build)
# ============================================================
set -euo pipefail

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
MODULE_DIR="$REPO_DIR/module"
OUT_DIR="${OUT_DIR:-$(pwd)/build}"
TARGET_ABI="${TARGET_ABI:-arm64-v8a}"
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
  echo "$tag"
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
    info "node: 从 $repo 查找最新 node-android-${NODE_ARCH}-* release ..."
    local json ver rel
    json=$(curl -fsSL --max-time 30 "https://api.github.com/repos/$repo/releases?per_page=100")
    # 扫描全部 release tag, 取该架构版本号最大者 (release 按版本归档, 保留历史)
    ver=$(echo "$json" | grep -oE '"tag_name": "node-android-'"${NODE_ARCH}"'-[0-9.]+"' \
      | sed -E 's/.*"node-android-'"${NODE_ARCH}"'-([0-9.]+)".*/\1/' | sort -V | tail -n 1)
    [ -n "$ver" ] || die "未找到 node-android-${NODE_ARCH}-* release (需要先构建 node-android-build 仓库)"
    # 从该 release 的实际资产中取下载地址 (顺带验证产物存在)
    rel=$(curl -fsSL --max-time 30 "https://api.github.com/repos/$repo/releases/tags/node-android-${NODE_ARCH}-${ver}")
    url=$(echo "$rel" | grep -oE '"browser_download_url": "[^"]*node-android-'"${NODE_ARCH}"'-'"${ver}"'\.tar\.xz"' \
      | head -n 1 | sed -E 's/.*"browser_download_url": "([^"]+)".*/\1/')
    [ -n "$url" ] || die "release node-android-${NODE_ARCH}-${ver} 中未找到 node-android-${NODE_ARCH}-${ver}.tar.xz 资产"
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

# ---------- 1. 拷贝模块源码 ----------
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -r "$MODULE_DIR/." "$STAGE/"
find "$STAGE" -name .DS_Store -delete

# ---------- 2. 组件 ----------
# 仓库内已预置 module/sub_store/bin 时直接使用, 否则在线获取
if [ ! -d "$STAGE/sub_store/bin" ]; then
  info "在线获取组件 ..."
  mkdir -p "$STAGE/sub_store/bin"
  fetch_node        "$STAGE/sub_store/bin"
  fetch_backend     "$STAGE/sub_store/bin"
  fetch_frontend    "$STAGE/sub_store/bin"
  fetch_http_meta   "$STAGE/sub_store/bin"
fi

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

# ---------- 3. META-INF (官方 module_installer.sh), 失败则跳过 ----------
mkdir -p "$STAGE/META-INF/com/google/android"
if download "https://raw.githubusercontent.com/topjohnwu/Magisk/master/scripts/module_installer.sh" \
  "$STAGE/META-INF/com/google/android/update-binary"; then
  printf '#MAGISK\n' > "$STAGE/META-INF/com/google/android/updater-script"
  info "已获取官方 module_installer.sh (支持恢复模式刷入)"
else
  rm -rf "$STAGE/META-INF"
  warn "获取 module_installer.sh 失败, 跳过 META-INF (管理器内安装不受影响)"
fi

# ---------- 4. 版本 (参考 ZygiskNext: versionCode=git 提交数, version 附带短 hash) ----------
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

# ---------- 5. updateJson (各架构分开, 由 workflow 发布到 gh-pages 分支) ----------
UPDATE_JSON_BASE="${UPDATE_JSON_BASE:-https://raw.githubusercontent.com/Delusions6515/Sub-Store-Module/gh-pages}"
sed -i "/^updateJson=/d" "$STAGE/module.prop"
echo "updateJson=$UPDATE_JSON_BASE/update-${TARGET_ABI}.json" >> "$STAGE/module.prop"
info "updateJson: $UPDATE_JSON_BASE/update-${TARGET_ABI}.json"

# ---------- 6. 权限 ----------
find "$STAGE" -type f \( -name '*.sh' -o -name 'sub_store.service' -o -name 'sub_store.inotify' -o -name 'update-binary' \) -exec chmod 755 {} +
find "$STAGE" -type d -exec chmod 755 {} +
chmod 755 "$STAGE/sub_store/bin/sub_store_node" "$STAGE/sub_store/bin/http-meta/http-meta"

# ---------- 7. 打包 ----------
mkdir -p "$OUT_DIR"
if [ -z "$OUT_ZIP" ]; then
  SUFFIX=""
  [ "$TARGET_ABI" != "arm64-v8a" ] && SUFFIX="-${TARGET_ABI}"
  OUT_ZIP="$OUT_DIR/sub-store-module-${VER_NAME}-${VER_CODE}-${VER_HASH}-${BUILD_TYPE}${SUFFIX}.zip"
fi
rm -f "$OUT_ZIP"
(cd "$STAGE" && zip -rq "$OUT_ZIP" .)

echo
info "已生成: $OUT_ZIP"
info "内置组件版本:"
[ -f "$STAGE/sub_store/bin/node_version" ]     && echo "  node:      $(cat "$STAGE/sub_store/bin/node_version")"
echo "  后端:     $(cat "$STAGE/sub_store/bin/backend_version")"
echo "  前端:     $(cat "$STAGE/sub_store/bin/frontend_version")"
echo "  mihomo:   $(cat "$STAGE/sub_store/bin/http-meta/kernel_version")"
ls -lh "$OUT_ZIP"
