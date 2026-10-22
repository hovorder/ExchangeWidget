#!/usr/bin/env bash
# 从源码构建 ExchangeWidget.app，可选安装到 /Applications 并自签名
set -euo pipefail

APP_NAME="ExchangeWidget"
SRC="Sources/main.swift"
HTML="Resources/exchange-widget.html"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ 编译 Swift..."
swiftc "$SRC" -O -o "$APP/Contents/MacOS/$APP_NAME"

echo "→ 拷贝资源..."
cp "$HTML" "$APP/Contents/Resources/"

if [ "${1:-}" = "--install" ]; then
  TARGET="/Applications/$APP_NAME.app"
  echo "→ 安装到 $TARGET..."
  rm -rf "$TARGET"
  cp -R "$APP" "$TARGET"
  xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
  codesign --force --deep --sign - "$TARGET"
  echo "✓ 已安装，双击或从菜单栏 💱 打开"
fi

echo "✓ 构建完成: $APP"
