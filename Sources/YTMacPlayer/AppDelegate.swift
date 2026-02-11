import Cocoa
import WebKit

// UserDefaults keys for persisting window state
private enum Defaults {
    static let windowX = "windowX"
    static let windowY = "windowY"
    static let windowWidth = "windowWidth"
    static let windowHeight = "windowHeight"
    static let windowOpacity = "windowOpacity"
}

class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler {

    private var panel: FloatingPanel!
    private var webView: YouTubeWebView!

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activate the app so it appears in Dock and Cmd+Tab
        NSApp.setActivationPolicy(.regular)

        // Create the floating panel at saved or default position
        let frame = savedWindowFrame()
        panel = FloatingPanel(contentRect: frame)

        // Create the YouTube webview filling the panel
        // Pass self as message handler so we receive video aspect ratio from JS
        webView = YouTubeWebView(frame: panel.contentView!.bounds, messageHandler: self)
        webView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(webView)

        // Restore saved opacity (default 100%)
        let opacity = CGFloat(UserDefaults.standard.double(forKey: Defaults.windowOpacity))
        panel.alphaValue = opacity > 0.19 ? opacity : 1.0

        // Set up the menu bar
        setupMenuBar()

        // Watch for window moves/resizes to save state
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidChangeFrame),
            name: NSWindow.didMoveNotification, object: panel
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidChangeFrame),
            name: NSWindow.didResizeNotification, object: panel
        )

        // Show the window and load YouTube
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        webView.loadYouTube()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWindowState()
    }

    // MARK: - Window State Persistence

    /// Returns the saved window frame, or a default 320x240 in the bottom-right corner.
    private func savedWindowFrame() -> NSRect {
        let defaults = UserDefaults.standard

        // Check if we have saved values (windowWidth > 0 means we've saved before)
        let savedWidth = defaults.double(forKey: Defaults.windowWidth)
        if savedWidth > 0 {
            let rect = NSRect(
                x: defaults.double(forKey: Defaults.windowX),
                y: defaults.double(forKey: Defaults.windowY),
                width: savedWidth,
                height: defaults.double(forKey: Defaults.windowHeight)
            )

            // Offscreen recovery: check if the saved position is visible on any screen
            if isRectVisibleOnAnyScreen(rect) {
                return rect
            }
        }

        // Default: 320x240, bottom-right corner of main screen
        return defaultWindowFrame()
    }

    /// 320x240 positioned in the bottom-right corner of the main screen, with padding.
    private func defaultWindowFrame() -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width: CGFloat = 320
        let height: CGFloat = 240
        let padding: CGFloat = 20
        return NSRect(
            x: screenFrame.maxX - width - padding,
            y: screenFrame.minY + padding,
            width: width,
            height: height
        )
    }

    /// Check if at least part of the window is visible on any connected screen.
    private func isRectVisibleOnAnyScreen(_ rect: NSRect) -> Bool {
        for screen in NSScreen.screens {
            if screen.visibleFrame.intersects(rect) {
                return true
            }
        }
        return false
    }

    /// Save current window frame and opacity to UserDefaults.
    private func saveWindowState() {
        let frame = panel.frame
        let defaults = UserDefaults.standard
        defaults.set(frame.origin.x, forKey: Defaults.windowX)
        defaults.set(frame.origin.y, forKey: Defaults.windowY)
        defaults.set(frame.size.width, forKey: Defaults.windowWidth)
        defaults.set(frame.size.height, forKey: Defaults.windowHeight)
        defaults.set(Double(panel.alphaValue), forKey: Defaults.windowOpacity)
    }

    @objc private func windowDidChangeFrame(_ notification: Notification) {
        saveWindowState()
    }

    // MARK: - Aspect Ratio Lock

    /// Receives messages from JavaScript: video aspect ratio and window drag deltas.
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }

        switch message.name {
        case "aspectRatio":
            // Lock window aspect ratio to match the video's native dimensions
            if let width = body["width"] as? CGFloat,
               let height = body["height"] as? CGFloat,
               width > 0, height > 0 {
                panel.contentAspectRatio = NSSize(width: width, height: height)
            }

        case "windowDrag":
            // Move the window by the drag delta from JavaScript
            if let dx = body["dx"] as? CGFloat,
               let dy = body["dy"] as? CGFloat {
                var origin = panel.frame.origin
                origin.x += dx
                origin.y -= dy  // macOS Y-axis is flipped (0 is bottom)
                panel.setFrameOrigin(origin)
            }

        default:
            break
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About YT Mac Player", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit YT Mac Player", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Reload Page", action: #selector(reloadPage), keyEquivalent: "r")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Increase Opacity", action: #selector(increaseOpacity), keyEquivalent: "+")
        viewMenu.items.last?.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(withTitle: "Decrease Opacity", action: #selector(decreaseOpacity), keyEquivalent: "-")
        viewMenu.items.last?.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Reset Window Position", action: #selector(resetWindowPosition), keyEquivalent: "")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.close), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu Actions

    @objc private func reloadPage() {
        webView.reloadPage()
    }

    @objc private func increaseOpacity() {
        let newOpacity = min(panel.alphaValue + 0.1, 1.0)
        panel.alphaValue = newOpacity
        saveWindowState()
    }

    @objc private func decreaseOpacity() {
        // Floor at 20% to prevent invisible window
        let newOpacity = max(panel.alphaValue - 0.1, 0.2)
        panel.alphaValue = newOpacity
        saveWindowState()
    }

    @objc private func resetWindowPosition() {
        panel.setFrame(defaultWindowFrame(), display: true, animate: true)
        saveWindowState()
    }
}

