#!/usr/bin/env bash
# 从源码构建 ExchangeWidget.app，可选安装到 /Applications 并自签名
set -euo pipefail

APP_NAME="ExchangeWidget"
SRC="Sources/main.swift"
HTML="Resources/exchange-widget.html"
ICON="Resources/AppIcon.icns"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ 编译 Swift..."
swiftc "$SRC" -O -o "$APP/Contents/MacOS/$APP_NAME"

echo "→ 生成 Info.plist..."
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>汇率桌面插件</string>
    <key>CFBundleDisplayName</key>     <string>汇率桌面插件</string>
    <key>CFBundleIdentifier</key>      <string>com.local.exchangewidget</string>
    <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
    <key>CFBundleVersion</key>         <string>1.0</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundleIconName</key>        <string>AppIcon</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
    <key>LSMinimumSystemVersion</key>  <string>11.0</string>
</dict>
</plist>
PLIST

echo "→ 拷贝资源..."
cp "$HTML" "$APP/Contents/Resources/"
cp "$ICON" "$APP/Contents/Resources/" 2>/dev/null || echo "⚠️ 未找到 $ICON，请先生成图标"

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
