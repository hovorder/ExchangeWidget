# ExchangeWidget

macOS 原生菜单栏汇率换算 + 计算器浮窗。轻量、无 Electron、无第三方依赖。

## 功能

- **实时汇率换算**：免费 API（open.er-api.com，无需 key），每 60 秒刷新
- **iOS 计算器风格行式布局**：第 1 行固定 CNY，其余行可切换币种；任意行输入，全行联动换算
- **内置简易计算器**：四则运算 + 物理键盘输入 + 历史记录
- **结果回填汇率**：计算结果一键写入任意汇率行（弹出币种选择）
- **菜单栏镂空图标**：单击开关窗口、点窗口外自动隐藏、右键退出
- **登录自启**：通过 LaunchAgent 实现

## 技术栈

- Swift 6（AppKit + WKWebView）做原生外壳
- 纯 HTML / CSS / JS 做全部 UI 与业务逻辑（加载于 WKWebView）

## 目录结构

```
Sources/main.swift                          # 原生外壳：面板 / 状态栏图标 / 拖拽 / 桥接
Resources/exchange-widget.html              # 全部 UI 与业务逻辑
LaunchAgent/com.hovord.exchangewidget.plist # 登录自启模板
build.sh                                    # 编译 + 签名 + 可选安装
```

## 构建

需要 Xcode Command Line Tools：

```bash
xcode-select --install
```

```bash
./build.sh            # 在 build/ 下生成 ExchangeWidget.app
./build.sh --install  # 额外安装到 /Applications 并自签名
```

> 自签名（`codesign --sign -`）仅够本地运行；若要分发给他人需 Developer ID 签名。

## 使用

| 操作 | 说明 |
|------|------|
| 左键菜单栏 💱 图标 | 开关窗口 |
| 点击窗口外 | 自动隐藏 |
| 右键菜单栏图标 | 退出 |
| 汇率视图 · 任意行输入 | 全行联动换算 |
| 汇率视图 · 点 ⌄ | 切换该币种 |
| 汇率视图 · + 添加货币 | 增加一行 |
| 计算视图 · 按钮 / 键盘 | `0-9` `+-*/` `Enter(=)` `Backspace(⌫)` `Esc(AC)` `%` |
| 计算视图 · ↩ 填入汇率 ▾ | 选币种，把结果回填该行 |

## 登录自启

```bash
cp LaunchAgent/com.hovord.exchangewidget.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.hovord.exchangewidget.plist
```

## 许可

[MIT](LICENSE)
