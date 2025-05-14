// In your AppDelegate.swift file:
import Cocoa
import SwiftUI
import HotKey  // Ensure you have the HotKey package added

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var hotKey: HotKey!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create a window for our test
        let contentView = SearchMapIntegrationTest()
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Address Autocomplete Test"
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        // Setup hotkey if needed
        hotKey = HotKey(key: .g, modifiers: [.command, .option])
        hotKey.keyDownHandler = { [weak self] in
            print("Hotkey triggered!")
            self?.toggleWindow()
        }
    }
    
    func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
            print("Window hidden")
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            print("Window shown")
        }
    }
}
