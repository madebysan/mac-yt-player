import Cocoa

// Entry point — creates the app, assigns the delegate, and starts the run loop
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
