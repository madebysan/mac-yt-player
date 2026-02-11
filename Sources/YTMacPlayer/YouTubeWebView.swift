import Cocoa
import WebKit

/// WKWebView configured to load YouTube with persistent cookies and Safari user-agent.
/// Uses non-ephemeral data store so Google login survives app restarts.
class YouTubeWebView: WKWebView {

    // Safari on macOS user-agent string — YouTube serves full site to Safari
    private static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    // JavaScript that makes the video fill the webview when the user clicks
    // YouTube's fullscreen button. Key design: we never dispatch fullscreenchange
    // events or let YouTube's player enter its own fullscreen mode. YouTube's
    // player stays in normal mode — we purely toggle CSS to hide the chrome
    // and expand the player. This avoids YouTube setting screen-sized pixel
    // values on the video that break everything.
    private static let fullscreenOverrideJS = """
    (function() {
        let isCustomFullscreen = false;

        const style = document.createElement('style');
        style.textContent = `
            /* When active: player fills viewport, all YouTube chrome hidden */
            body.yt-mac-fs #masthead-container,
            body.yt-mac-fs #page-manager ytd-watch-flexy #secondary,
            body.yt-mac-fs #page-manager ytd-watch-flexy #below,
            body.yt-mac-fs #page-manager ytd-watch-flexy #related,
            body.yt-mac-fs #page-manager ytd-watch-flexy #comments,
            body.yt-mac-fs #page-manager ytd-watch-flexy #chat,
            body.yt-mac-fs #page-manager ytd-watch-flexy #meta,
            body.yt-mac-fs #page-manager ytd-watch-flexy #info-contents {
                display: none !important;
            }
            body.yt-mac-fs {
                overflow: hidden !important;
            }
            body.yt-mac-fs #page-manager {
                margin-top: 0 !important;
            }
            body.yt-mac-fs #full-bleed-container,
            body.yt-mac-fs #player-full-bleed-container,
            body.yt-mac-fs ytd-watch-flexy #player-container,
            body.yt-mac-fs ytd-watch-flexy #player-container-outer,
            body.yt-mac-fs ytd-watch-flexy #player-container-inner,
            body.yt-mac-fs ytd-watch-flexy #ytd-player,
            body.yt-mac-fs ytd-watch-flexy #player-wide-container,
            body.yt-mac-fs ytd-watch-flexy .ytd-player,
            body.yt-mac-fs #movie_player {
                position: fixed !important;
                top: 0 !important;
                left: 0 !important;
                width: 100vw !important;
                height: 100vh !important;
                max-height: none !important;
                min-height: 0 !important;
                z-index: 999999 !important;
                background: black !important;
                margin: 0 !important;
                padding: 0 !important;
            }
            body.yt-mac-fs .html5-video-container {
                width: 100% !important;
                height: 100% !important;
            }
            body.yt-mac-fs video.html5-main-video {
                width: 100% !important;
                height: 100% !important;
                object-fit: contain !important;
                position: relative !important;
                top: 0 !important;
                left: 0 !important;
            }
            body.yt-mac-fs .ytp-chrome-bottom {
                z-index: 1000000 !important;
            }
        `;

        function injectStyles() {
            if (document.head) {
                document.head.appendChild(style);
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    document.head.appendChild(style);
                });
            }
        }
        injectStyles();

        function toggle() {
            isCustomFullscreen = !isCustomFullscreen;
            if (isCustomFullscreen) {
                document.body.classList.add('yt-mac-fs');
            } else {
                document.body.classList.remove('yt-mac-fs');
            }
        }

        // Intercept ALL clicks on YouTube's fullscreen button in the capture
        // phase, before YouTube's own handler runs. We stop propagation so
        // YouTube never enters its own fullscreen mode.
        document.addEventListener('click', function(e) {
            const fsBtn = e.target.closest('.ytp-fullscreen-button');
            if (fsBtn) {
                e.stopPropagation();
                e.preventDefault();
                toggle();
            }
        }, true);

        // 'f' key is YouTube's fullscreen shortcut — intercept it too
        document.addEventListener('keydown', function(e) {
            if (e.key === 'f' && !e.metaKey && !e.ctrlKey && !e.altKey) {
                const tag = (e.target.tagName || '').toLowerCase();
                // Don't intercept if user is typing in a text field
                if (tag === 'input' || tag === 'textarea' || e.target.isContentEditable) return;
                e.stopPropagation();
                e.preventDefault();
                toggle();
            }
            // Escape exits our custom fullscreen
            if (e.key === 'Escape' && isCustomFullscreen) {
                e.stopPropagation();
                e.preventDefault();
                toggle();
            }
        }, true);

        // Double-click on video toggles fullscreen (YouTube's default behavior)
        document.addEventListener('dblclick', function(e) {
            if (e.target.closest('#movie_player') && (e.target.tagName === 'VIDEO' || e.target.closest('.html5-video-container'))) {
                e.stopPropagation();
                e.preventDefault();
                toggle();
            }
        }, true);

        // Report fullscreen as supported so YouTube doesn't show an error
        Object.defineProperty(document, 'fullscreenEnabled', {
            get: function() { return true; }, configurable: true
        });
        Object.defineProperty(document, 'webkitFullscreenEnabled', {
            get: function() { return true; }, configurable: true
        });

        // No-op the Fullscreen API so any direct calls don't break anything
        Element.prototype.requestFullscreen = function() { return Promise.resolve(); };
        Element.prototype.webkitRequestFullscreen = function() {};
        Element.prototype.webkitRequestFullScreen = function() {};
        document.exitFullscreen = function() { return Promise.resolve(); };
        document.webkitExitFullscreen = function() {};
        document.webkitCancelFullScreen = function() {};

        // Always report not in native fullscreen
        Object.defineProperty(document, 'fullscreenElement', {
            get: function() { return null; }, configurable: true
        });
        Object.defineProperty(document, 'webkitFullscreenElement', {
            get: function() { return null; }, configurable: true
        });
        Object.defineProperty(document, 'webkitCurrentFullScreenElement', {
            get: function() { return null; }, configurable: true
        });
    })();
    """

    // JavaScript that detects the playing video's native dimensions and sends
    // them to Swift so we can lock the window's aspect ratio. Polls every 2s
    // because YouTube is a SPA — videos change without full page reloads.
    private static let aspectRatioJS = """
    (function() {
        let lastW = 0, lastH = 0;
        function check() {
            const video = document.querySelector('video.html5-main-video');
            if (video && video.videoWidth > 0 && video.videoHeight > 0) {
                if (video.videoWidth !== lastW || video.videoHeight !== lastH) {
                    lastW = video.videoWidth;
                    lastH = video.videoHeight;
                    window.webkit.messageHandlers.aspectRatio.postMessage({
                        width: lastW,
                        height: lastH
                    });
                }
            }
        }
        setInterval(check, 2000);
        document.addEventListener('DOMContentLoaded', function() {
            // Also listen for loadedmetadata on any video element
            new MutationObserver(function() {
                const video = document.querySelector('video.html5-main-video');
                if (video) {
                    video.addEventListener('loadedmetadata', check);
                }
            }).observe(document.body || document.documentElement, { childList: true, subtree: true });
        });
    })();
    """

    // JavaScript that enables window dragging by click-dragging on non-interactive
    // areas (the video, empty space). Uses a 4px threshold so normal clicks still
    // pass through to YouTube for play/pause. Only left-click drags.
    private static let windowDragJS = """
    (function() {
        let drag = null;

        document.addEventListener('mousedown', function(e) {
            if (e.button !== 0) return;
            // Don't drag from YouTube controls, links, buttons, inputs
            const interactive = e.target.closest(
                'a, button, input, textarea, select, [role="button"], [role="slider"], ' +
                '.ytp-chrome-bottom, .ytp-chrome-top, .ytp-progress-bar, ' +
                '.ytp-scrubber-container, .ytp-settings-menu, .ytp-popup, ' +
                '.ytp-ce-element, ytd-searchbox, #search'
            );
            if (interactive) return;
            drag = { startX: e.screenX, startY: e.screenY, lastX: e.screenX, lastY: e.screenY, active: false };
        }, false);

        document.addEventListener('mousemove', function(e) {
            if (!drag) return;
            if (!drag.active) {
                // 4px threshold before we consider it a drag
                const dx = Math.abs(e.screenX - drag.startX);
                const dy = Math.abs(e.screenY - drag.startY);
                if (dx < 4 && dy < 4) return;
                drag.active = true;
            }
            const dx = e.screenX - drag.lastX;
            const dy = e.screenY - drag.lastY;
            drag.lastX = e.screenX;
            drag.lastY = e.screenY;
            window.webkit.messageHandlers.windowDrag.postMessage({ dx: dx, dy: dy });
            e.preventDefault();
        }, false);

        document.addEventListener('mouseup', function(e) {
            drag = null;
        }, false);
    })();
    """

    init(frame: CGRect, messageHandler: WKScriptMessageHandler) {
        let config = WKWebViewConfiguration()

        // Non-ephemeral = cookies persist in ~/Library/WebKit/ across launches
        config.websiteDataStore = WKWebsiteDataStore.default()

        // Set Safari user-agent so YouTube doesn't block us
        config.applicationNameForUserAgent = "Version/17.0 Safari/605.1.15"

        // Disable native fullscreen — we handle it ourselves via JS override
        config.preferences.isElementFullscreenEnabled = false

        // Inject our fullscreen override before any page scripts run
        let fsScript = WKUserScript(
            source: YouTubeWebView.fullscreenOverrideJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(fsScript)

        // Inject aspect ratio detection (at document end so the DOM is ready)
        let arScript = WKUserScript(
            source: YouTubeWebView.aspectRatioJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(arScript)

        // Inject window drag handling (at document end so the DOM is ready)
        let dragScript = WKUserScript(
            source: YouTubeWebView.windowDragJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(dragScript)

        // Register message handlers so JS can communicate with Swift
        config.userContentController.add(messageHandler, name: "aspectRatio")
        config.userContentController.add(messageHandler, name: "windowDrag")

        super.init(frame: frame, configuration: config)

        // Override the full user-agent string
        customUserAgent = YouTubeWebView.safariUserAgent

        // Allow back/forward swipe gestures
        allowsBackForwardNavigationGestures = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    /// Load YouTube Watch Later playlist
    func loadYouTube() {
        guard let url = URL(string: "https://www.youtube.com/playlist?list=WL") else { return }
        load(URLRequest(url: url))
    }

    /// Reload the current page (for Cmd+R)
    func reloadPage() {
        reload()
    }
}
