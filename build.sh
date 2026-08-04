#!/bin/bash
# ============================================================
# Sub-Store for Android - 模块构建脚本
#
# 用法:
#   ./build.sh                 # 使用 module.prop 中的版本构建
#   ./build.sh v2.1.0          # 指定版本构建 (versionCode 自动取当前时间戳)
#   ./build.sh v2.1.0 out.zip  # 指定版本和输出路径
#
# 环境变量:
#   SUBSTORE_REF_ZIP  内置二进制来源 zip。不设置时依次查找:
#                     当前目录 / 仓库目录下的 "Sub-Store for Android.zip";
#                     也可以预先解压二进制到 module/sub_store/bin/ 直接使用
#   OUT_DIR           输出目录 (默认 ./build)
# ============================================================
set -euo pipefail

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
MODULE_DIR="$REPO_DIR/module"
OUT_DIR="${OUT_DIR:-$(pwd)/build}"
VERSION="${1:-}"
OUT_ZIP="${2:-}"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

echo "[*] 构建 Sub-Store for Android 模块"

# ---------- 1. 拷贝模块源码 ----------
cp -r "$MODULE_DIR/." "$STAGE/"
find "$STAGE" -name .DS_Store -delete

# ---------- 2. 内置二进制 ----------
# 优先级: 仓库内已有 module/sub_store/bin > SUBSTORE_REF_ZIP > 当前目录/仓库目录的参考 zip
if [ ! -d "$STAGE/sub_store/bin" ]; then
  REF_ZIP="${SUBSTORE_REF_ZIP:-}"
  if [ -z "$REF_ZIP" ] && [ -f "$PWD/Sub-Store for Android.zip" ]; then
    REF_ZIP="$PWD/Sub-Store for Android.zip"
  fi
  if [ -z "$REF_ZIP" ] && [ -f "$REPO_DIR/Sub-Store for Android.zip" ]; then
    REF_ZIP="$REPO_DIR/Sub-Store for Android.zip"
  fi
  if [ -z "$REF_ZIP" ]; then
    echo "[Error] 未找到内置二进制来源"
    echo "        请任选其一:"
    echo "        1) 设置环境变量 SUBSTORE_REF_ZIP 指向参考 zip"
    echo "        2) 将参考 zip 放到当前目录或仓库目录 (文件名: Sub-Store for Android.zip)"
    echo "        3) 预先解压二进制到 $MODULE_DIR/sub_store/bin/"
    exit 1
  fi
  echo "[*] 从参考 zip 提取内置二进制: $REF_ZIP"
  mkdir -p "$STAGE/sub_store"
  unzip -q -o "$REF_ZIP" 'sub_store/bin/*' -d "$STAGE/ref_tmp"
  mv "$STAGE/ref_tmp/sub_store/bin" "$STAGE/sub_store/bin"
  rm -rf "$STAGE/ref_tmp"
  find "$STAGE/sub_store" -name .DS_Store -delete
fi

# 校验关键文件
for f in \
  sub_store/bin/sub_store_node \
  sub_store/bin/sub-store.bundle.js \
  sub_store/bin/http-meta.bundle.js \
  sub_store/bin/http-meta/http-meta \
  sub_store/bin/http-meta/tpl.yaml \
  sub_store/bin/frontend/index.html; do
  if [ ! -e "$STAGE/$f" ]; then
    echo "[Error] 缺少内置文件: $f"
    exit 1
  fi
done

# ---------- 3. META-INF (官方 module_installer.sh), 失败则跳过 ----------
# 管理器内安装不需要 META-INF, 仅恢复模式刷入需要
if [ ! -d "$STAGE/META-INF" ]; then
  mkdir -p "$STAGE/META-INF/com/google/android"
  if curl -fsSL --max-time 30 \
    "https://raw.githubusercontent.com/topjohnwu/Magisk/master/scripts/module_installer.sh" \
    -o "$STAGE/META-INF/com/google/android/update-binary"; then
    printf '#MAGISK\n' > "$STAGE/META-INF/com/google/android/updater-script"
    echo "[*] 已获取官方 module_installer.sh (支持恢复模式刷入)"
  else
    rm -rf "$STAGE/META-INF"
    echo "[!] 获取 module_installer.sh 失败, 跳过 META-INF (管理器内安装不受影响)"
  fi
fi

# ---------- 4. 版本 ----------
if [ -n "$VERSION" ]; then
  VERSION_CODE="${VERSION_CODE:-$(date +%s)}"
  sed -i "s/^version=.*/version=$VERSION/; s/^versionCode=.*/versionCode=$VERSION_CODE/" "$STAGE/module.prop"
  echo "[*] 版本: $VERSION (versionCode: $VERSION_CODE)"
fi

# ---------- 5. 权限 ----------
find "$STAGE" -type f \( -name '*.sh' -o -name 'update-binary' \) -exec chmod 755 {} +
find "$STAGE" -type d -exec chmod 755 {} +

# ---------- 6. 打包 ----------
mkdir -p "$OUT_DIR"
if [ -z "$OUT_ZIP" ]; then
  OUT_ZIP="$OUT_DIR/sub-store-module-$(sed -n 's/^version=//p' "$STAGE/module.prop").zip"
fi
rm -f "$OUT_ZIP"
(cd "$STAGE" && zip -rq "$OUT_ZIP" .)

echo "[*] 已生成: $OUT_ZIP"
echo "[*] 模块结构:"
unzip -l "$OUT_ZIP" | grep -vE 'sub_store/bin/frontend/' | head -40
echo "[*] 内置二进制: $(unzip -l "$OUT_ZIP" | grep -cE 'sub_store/bin/') 个文件"
