# YT Mac Player

A minimal macOS app that floats a YouTube window above all other apps, designed for watching playlists while working. No ads, no API complexity — just your YouTube Premium account in an always-on-top window.

**Key Features:**

- Always-on-top floating window that never gets buried
- Persistent login — sign in once, cookies survive restarts
- Custom fullscreen mode that fills the window without entering macOS fullscreen
- Automatic aspect ratio locking — window resizes match the video's dimensions
- Drag anywhere on the video to reposition the window
- Adjustable transparency (20%-100%)
- Opens directly to your Watch Later playlist
- No dependencies, no YouTube API, no OAuth hassle

---

## Screenshot

*Screenshot placeholder — add a screen capture showing the app floating over other windows*

---

## Requirements

- macOS 13.0 (Ventura) or later
- YouTube Premium recommended (no ads during playback)
- No other dependencies — this is a self-contained app

---

## Installation

### Option 1: Install from DMG (Recommended)

1. Download `YT-Mac-Player.dmg` from the [latest release](https://github.com/madebysan/yt-mac-player/releases/latest)
2. Open the DMG file
3. Drag "YT Mac Player" to the Applications folder
4. Eject the DMG
5. Launch the app — it's signed and notarized, so no Gatekeeper warnings

### Option 2: Build from Source

Clone the repository and build with Swift Package Manager:

```bash
git clone https://github.com/madebysan/yt-mac-player.git
cd yt-mac-player
swift build -c release
```

Run directly:

```bash
swift run
```

Or build and install as an app bundle using the included script:

```bash
./scripts/build-dmg.sh
```

This creates `dist/YT Mac Player.app` and `dist/YT-Mac-Player.dmg`.

---

## First Launch

### Logging into Google

The first time the app launches, you'll see the YouTube homepage but won't be logged in.

1. Click "Sign In" in the top-right corner
2. Log in with your Google account
3. Complete any two-factor authentication if prompted

Your login is saved in persistent cookies stored in `~/Library/WebKit/`. The app will stay logged in across restarts, even if you close it for days or weeks.

If you ever need to switch accounts, just sign out within the app's YouTube page and sign back in with a different account.

---

## Usage

### Daily Workflow

1. **Launch the app** — it opens directly to your Watch Later playlist
2. **Click a video** to start watching
3. **Enter fullscreen mode** by pressing `f` or clicking YouTube's fullscreen button
   - This is a custom fullscreen-in-window mode, not native macOS fullscreen
   - The video fills the window, YouTube's chrome (header, sidebar, comments) disappears
   - Your other apps remain accessible — no switching Spaces or desktops
4. **Exit fullscreen** by pressing `f` again or `Escape`
5. **Reposition the window** by dragging anywhere on the video (not just the title bar)
6. **Resize the window** from any edge or corner
   - The aspect ratio automatically locks to match the video's dimensions
   - No stretching or black bars — it just works
7. **Adjust transparency** with `Cmd+` to increase or `Cmd-` to decrease
   - Range: 20% to 100% opacity
   - Minimum of 20% prevents losing track of an invisible window

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Q` | Quit the app |
| `Cmd+W` | Close the window (same as quitting) |
| `Cmd+R` | Reload the page |
| `Cmd+M` | Minimize to Dock |
| `Cmd++` | Increase opacity by 10% |
| `Cmd+-` | Decrease opacity by 10% (minimum 20%) |
| `f` | Toggle fullscreen mode (when focused on video, not typing) |
| `Escape` | Exit fullscreen mode |
| `Space` | Play/pause (YouTube default) |
| `Left/Right Arrow` | Seek backward/forward 5 seconds (YouTube default) |
| `Up/Down Arrow` | Volume up/down (YouTube default) |
| Media keys | Play, pause, next, previous (when window is focused) |

### Double-Click to Fullscreen

You can also double-click anywhere on the video to toggle fullscreen mode. This mimics YouTube's default behavior.

### Opacity Control

The window's transparency helps it blend into your workspace without being distracting.

- Default: 100% (fully opaque)
- Adjust via `Cmd+` and `Cmd-` in 10% increments
- Floor of 20% prevents the window from becoming invisible
- Opacity is saved and restored when you relaunch the app

---

## How It Works

This section explains the technical approach for curious readers.

### Always-on-Top Window

The app uses an `NSPanel` configured with `.floating` window level. This keeps it above all other windows — including full-screen apps (via the `fullScreenAuxiliary` collection behavior) — without stealing focus from your work.

The panel has no title bar and no traffic light buttons (close/minimize/maximize). It's a clean, borderless window that gets out of the way.

### Persistent Cookies

The app embeds a `WKWebView` (the same engine Safari uses) with a non-ephemeral data store. This means cookies are saved to `~/Library/WebKit/` automatically.

When you log into Google, the session cookies persist across app restarts. No OAuth, no API keys, no manual token management — it's just a browser that remembers you.

### Safari User-Agent

The webview identifies itself as Safari using a standard Safari user-agent string. This ensures YouTube serves the full desktop site instead of showing "unsupported browser" warnings.

### Custom Fullscreen Mode

This is the most clever part of the app.

**The problem:** YouTube's native fullscreen mode tries to use the browser's Fullscreen API, which triggers macOS's native fullscreen. This hides all other windows, switches Spaces/desktops, and defeats the purpose of a floating window.

**The solution:** The app injects JavaScript that intercepts YouTube's fullscreen button clicks before YouTube's own handler runs. Instead of entering native fullscreen, the JavaScript:

1. Hides YouTube's chrome (header, sidebar, comments, metadata)
2. Expands the player to fill the entire window using CSS (`position: fixed; width: 100vw; height: 100vh`)
3. Never dispatches `fullscreenchange` events or calls the Fullscreen API

YouTube's player stays in normal mode. The app's window stays floating. You get a fullscreen-looking video without losing access to your other apps.

The `f` key, YouTube's fullscreen button, and double-clicking the video are all intercepted this way. Pressing `Escape` exits the custom fullscreen mode.

### Automatic Aspect Ratio Locking

YouTube is a single-page app — videos change without full page reloads. The app needs to detect when a new video starts and lock the window's aspect ratio to match.

**How it works:**

1. JavaScript polls `video.videoWidth` and `video.videoHeight` every 2 seconds
2. When dimensions change, the script sends them to Swift via `WKScriptMessageHandler`
3. Swift sets the window's `contentAspectRatio` property to match
4. macOS enforces the aspect ratio during resize — no stretching, no black bars

This is why the window resizes feel so natural. The aspect ratio is always correct for the current video.

### Window Dragging

The window has no title bar, but you can still drag it. The app injects JavaScript that:

1. Detects `mousedown` events on non-interactive areas (the video, empty space)
2. Tracks `mousemove` events and calculates deltas
3. Sends the deltas to Swift via `WKScriptMessageHandler`
4. Swift moves the window by adjusting its `origin`

The script uses a 4-pixel movement threshold to distinguish drags from clicks, so normal play/pause clicks still work.

Interactive elements (buttons, links, sliders, the YouTube control bar) are excluded from dragging, so you can still interact with YouTube's UI normally.

### Window State Persistence

The app saves its window position, size, and opacity to `UserDefaults` every time you move, resize, or change opacity. On launch, it restores the saved state.

**Offscreen recovery:** If the saved position is no longer visible (e.g., you disconnected an external monitor), the app resets to the default position: 320x240 in the bottom-right corner of your main screen.

---

## Tech Stack

- **Language:** Swift
- **Framework:** AppKit (no SwiftUI — this is pure Cocoa)
- **WebView:** WKWebKit (Safari's rendering engine)
- **Build system:** Swift Package Manager
- **Deployment target:** macOS 13.0 (Ventura)
- **Dependencies:** None (zero third-party libraries)

The entire app is about 700 lines of Swift, including comments.

---

## Project Structure

```
yt-mac-player/
├── Package.swift                      # Swift Package Manager manifest
├── Info.plist                         # App metadata (bundle ID, version, icon)
├── Entitlements.entitlements          # App sandbox entitlements
├── LICENSE                            # MIT license
├── Sources/
│   └── YTMacPlayer/
│       ├── main.swift                 # Entry point (creates NSApp and delegate)
│       ├── AppDelegate.swift          # Window management, state persistence, menu bar
│       ├── FloatingPanel.swift        # NSPanel configured for always-on-top
│       ├── YouTubeWebView.swift       # WKWebView with fullscreen override JS
├── scripts/
│   ├── build-dmg.sh                   # Builds signed, notarized .app bundle and DMG
│   ├── generate-icon.swift            # Generates AppIcon.icns (red play button)
└── README.md                          # This file
```

**File descriptions:**

- `main.swift` — Creates the `NSApplication` instance, assigns the app delegate, and starts the event loop (7 lines)
- `AppDelegate.swift` — App lifecycle, window state persistence, menu bar setup, message handling from JavaScript (aspect ratio, window drag)
- `FloatingPanel.swift` — `NSPanel` subclass configured for floating behavior, no title bar, minimum size enforcement
- `YouTubeWebView.swift` — `WKWebView` subclass with Safari UA, fullscreen override JS, aspect ratio detection JS, window drag JS
- `build-dmg.sh` — Builds a release binary, packages it as a `.app` bundle, code signs + notarizes it, and wraps it in a DMG with an Applications symlink
- `generate-icon.swift` — Draws a YouTube-style icon (red rounded rect + white play triangle) and exports it as `.icns` for all required sizes

---

## Building

### Build the Binary

```bash
swift build -c release
```

The binary will be at `.build/release/YTMacPlayer`.

### Generate the App Icon

```bash
swift scripts/generate-icon.swift
```

This creates `AppIcon.icns` with a YouTube-style red play button.

### Build the DMG

```bash
./scripts/build-dmg.sh
```

This:

1. Builds the release binary
2. Creates a `.app` bundle at `dist/YT Mac Player.app`
3. Packages it into `dist/YT-Mac-Player.dmg` with an Applications symlink for drag-install

Open the DMG and drag the app to your Applications folder to install.

---

## Troubleshooting

### Login doesn't persist after quitting

The app uses a non-ephemeral `WKWebsiteDataStore`, which should save cookies automatically.

**Possible causes:**

- You might have cleared WebKit data via System Settings → Privacy & Security → Safari (this affects all WKWebView apps)
- The app's sandbox is interfering (this shouldn't happen unless you modified the build settings)

**Solution:** Log in again. If the problem persists, check `~/Library/WebKit/` to see if data is being written.

### YouTube shows "Your browser doesn't support fullscreen"

This shouldn't happen — the app's JavaScript overrides YouTube's fullscreen detection.

**If you see this:**

1. Press `Cmd+R` to reload the page
2. Check the browser console (you'd need to enable the Develop menu in Safari, then attach to the webview process) for JavaScript errors

### Window is lost offscreen

If the window is positioned on a disconnected monitor, it should auto-recover on launch.

**Manual recovery:**

- Go to **View → Reset Window Position** in the menu bar
- This moves the window to the default position (320x240, bottom-right corner)

---

## Known Limitations

- **No auto-update** — To update, download a new DMG from the [releases page](https://github.com/madebysan/yt-mac-player/releases) and replace the app manually
- **YouTube DOM changes** — If YouTube redesigns their player, the fullscreen override JavaScript might break. The app would need an update to fix the CSS selectors.

---

## License

MIT License — see LICENSE file for details.
