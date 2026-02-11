import Cocoa

/// NSPanel configured to float above all other windows without stealing focus.
/// This is the main window that contains the YouTube webview.
class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [
                .titled,           // Needed for resize handles to work
                .closable,
                .resizable,
                .miniaturizable,
                .nonactivatingPanel,
                .fullSizeContentView  // Content extends behind the title bar
            ],
            backing: .buffered,
            defer: false
        )

        // Hide the title bar — content fills the entire window
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        // Hide the traffic light buttons (close, minimize, maximize)
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // Float above all other windows
        level = .floating

        // Show on all Spaces / desktops, work alongside fullscreen apps
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Minimum size so YouTube controls remain usable
        minSize = NSSize(width: 280, height: 200)

        // Window title (not visible, but used for Cmd+Tab / accessibility)
        title = "YT Mac Player"

        // Allow the panel to become key (receive keyboard input) when clicked
        isFloatingPanel = true

        // Keep the window visible even when the app is not active
        hidesOnDeactivate = false

        // Allow moving the window by dragging anywhere on the background
        isMovableByWindowBackground = true
    }

    // Allow the panel to become the key window so keyboard input works
    // (media keys, typing in YouTube search, etc.)
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
