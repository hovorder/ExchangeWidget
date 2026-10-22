import AppKit
import WebKit

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class Controller: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    var panel: KeyPanel!
    var statusItem: NSStatusItem!
    var webView: WKWebView!
    var lastHiddenAt: TimeInterval = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        setupStatusItem()
    }

    func setupPanel() {
        let w: CGFloat = 360, h: CGFloat = 640
        panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                        styleMask: [.borderless],
                        backing: .buffered, defer: false)
        panel.level = .statusBar  // 与菜单栏同级，始终置顶
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false

        if let s = NSScreen.main {
            let r = panel.frame
            panel.setFrameOrigin(NSPoint(x: s.visibleFrame.maxX - r.width - 20,
                                         y: s.visibleFrame.maxY - r.height - 20))
        }

        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(self, name: "drag")
        cfg.userContentController.add(self, name: "ctl")
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: w, height: h), configuration: cfg)
        webView.autoresizingMask = [.width, .height]
        if webView.responds(to: Selector(("setDrawsBackground:"))) {
            webView.setValue(false, forKey: "drawsBackground")
        }
        panel.contentView = webView

        let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let candidates = [
            Bundle.main.url(forResource: "exchange-widget", withExtension: "html"),
            execDir.appendingPathComponent("../Resources/exchange-widget.html"),
            execDir.appendingPathComponent("exchange-widget.html")
        ]
        if let u = candidates.compactMap({ $0 }).first {
            webView.loadFileURL(u, allowingReadAccessTo: u.deletingLastPathComponent())
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.image = Self.badgeImage()
            b.image?.isTemplate = false
            b.action = #selector(toggle)
            b.target = self
            // 注意：绝不给 statusItem 设置 menu，否则 action 永远不会触发
            b.sendAction(on: [.leftMouseDown, .rightMouseDown])
            b.toolTip = "汇率插件 · 左键开/关，右键退出"
        }

        // 点击窗口外（失去焦点）自动隐藏
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
            object: panel, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.panel.isVisible {
                self.panel.orderOut(nil)
                self.lastHiddenAt = Date().timeIntervalSince1970
            }
        }
    }

    static func badgeImage() -> NSImage {
        // 镂空风格：浅白圆角方块 + ¥$ 符号透明镂空（透出菜单栏底色，与其他图标风格一致）
        // 注意：bitmapImageRep 上下文已自动做 点→2x像素 映射，切勿再 scaleBy
        let side: CGFloat = 22, scale: CGFloat = 2
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(side * scale), pixelsHigh: Int(side * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .calibratedRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: side, height: side)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
        // 合并路径：圆角方块 + ¥$ 字形，用 even-odd 一次填充 → 字形区域镂空
        let combined = NSBezierPath()
        combined.append(NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 20, height: 20),
                                     xRadius: 6.5, yRadius: 6.5))

        // 用 CoreText 取 "¥$" 的 CGGlyph，append 到 BezierPath（自动按字距排布）
        let cfStr = CFAttributedStringCreate(nil, "¥$" as CFString,
                                             [kCTFontAttributeName: font] as CFDictionary)!
        let ctLine = CTLineCreateWithAttributedString(cfStr)
        let runs = CTLineGetGlyphRuns(ctLine) as! [CTRun]
        var ascent: CGFloat = 0, descent: CGFloat = 0
        let textW = CTLineGetTypographicBounds(ctLine, &ascent, &descent, nil)
        var allG = [CGGlyph]()
        for run in runs {
            let cnt = CTRunGetGlyphCount(run)
            var gl = [CGGlyph](repeating: 0, count: cnt)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &gl)
            allG.append(contentsOf: gl)
        }
        let glyphPath = NSBezierPath()
        glyphPath.move(to: .zero)   // 空路径直接 append 字形会崩，需先 moveTo
        glyphPath.append(withCGGlyphs: allG, count: allG.count, in: font)
        let x0 = (side - CGFloat(textW)) / 2
        let y0 = (side - (ascent + descent)) / 2 + descent
        glyphPath.transform(using: AffineTransform(translationByX: x0, byY: y0))
        combined.append(glyphPath)

        combined.windingRule = .evenOdd
        NSColor(white: 1, alpha: 0.92).setFill()
        combined.fill()

        NSGraphicsContext.restoreGraphicsState()
        let img = NSImage(size: NSSize(width: side, height: side))
        img.addRepresentation(rep)
        img.isTemplate = false
        return img
    }

    @objc func toggle() {
        // 右键 → 弹出退出菜单
        if NSApp.currentEvent?.type == .rightMouseDown || NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: ""))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)   // 弹出菜单
            statusItem.menu = nil                  // 立即清空，恢复左键 action
            return
        }
        if panel.isVisible {
            panel.orderOut(nil)
            lastHiddenAt = Date().timeIntervalSince1970
        } else {
            // 过滤掉"点图标触发隐藏后又被同一动作重新打开"的竞态
            if Date().timeIntervalSince1970 - lastHiddenAt < 0.35 { return }
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func quit() { NSApp.terminate(nil) }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "drag",
           let d = message.body as? [String: Double],
           let dx = d["dx"], let dy = d["dy"] {
            var o = panel.frame.origin
            o.x += dx
            o.y -= dy
            panel.setFrameOrigin(o)
        } else if message.name == "ctl",
                  let d = message.body as? [String: String],
                  d["action"] == "close" {
            panel.orderOut(nil)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let c = Controller()
app.delegate = c
app.run()
