//
//  AppDelegate.swift
//  TEst
//
//  Created by anh.tran on 12/27/24.
//

import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    private var statusItem: NSStatusItem!
    private var clipboardManager: ClipboardManager!
    private var clipboardPanel: ClipboardPanel?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // MARK: - Lifecycle
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPermissions()
        setupStatusItem()
        setupClipboardManager()
        setupGlobalHotKey()
        
        // Register for panel show notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showPanelAtFocusedView),
            name: .showClipboardPanel,
            object: nil
        )
    }
    
    // MARK: - Setup Methods
    
    private func setupPermissions() {
        // Request accessibility permissions if needed
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessibilityEnabled {
            print("Please enable accessibility permissions in System Preferences")
        }
    }
    
    private func setupClipboardManager() {
        clipboardManager = ClipboardManager()
        clipboardManager.delegate = self
        clipboardManager.startMonitoring()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
        }
    }
    
    private func setupGlobalHotKey() {
        print("Setting up global hotkey...")
        
        // Check for accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            print("Accessibility permissions not granted")
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "To use global shortcuts (Option + V), please grant accessibility permissions to MacClipboardManager in System Preferences > Security & Privacy > Privacy > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Later")
            
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            return
        }
        
        print("Accessibility permissions granted")
        
        // Create event tap for keyboard events
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { [weak self] (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                print("Event received: \(type.rawValue)")
                
                if type == .keyDown {
                    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags
                    
                    print("Keycode: \(keycode), Flags: \(flags.rawValue)")
                    
                    // Check for Option + V (V keycode is 9)
                    if keycode == 9 && flags.contains(.maskAlternate) 
                        && !flags.contains(.maskCommand) && !flags.contains(.maskShift) && !flags.contains(.maskControl) {
                        print("Hotkey combination detected!")
                        
                        // Post notification to show panel on main thread
                        DispatchQueue.main.async {
                            print("Posting show panel notification")
                            NotificationCenter.default.post(name: .showClipboardPanel, object: nil)
                        }
                        return nil // Consume the event
                    }
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            print("Failed to create event tap")
            return
        }
        
        print("Event tap created successfully")
        
        // Store the event tap
        self.eventTap = tap
        
        // Create and add run loop source
        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            print("Failed to create run loop source")
            return
        }
        
        self.runLoopSource = runLoopSource
        
        // Add to current run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)
        
        print("Global shortcut enabled: Option + V")
        
        // Keep a strong reference to self while the event tap is active
        DispatchQueue.main.async { [self] in
            _ = self
        }
    }
    
    deinit {
        if let runLoopSource = self.runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        if let eventTap = self.eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }
    
    // MARK: - Actions
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        showClipboardPanel(at: NSPoint(x: sender.frame.minX, y: sender.frame.minY))
    }
    
    @objc private func showPanelAtFocusedView() {
        // Try to get the focused text field
        guard let keyWindow = NSApp.keyWindow,
              let firstResponder = keyWindow.firstResponder as? NSView else {
            // Fallback to mouse location if no text field is focused
            showClipboardPanel(at: NSEvent.mouseLocation)
            return
        }
        
        // Convert view frame to screen coordinates
        let fieldFrame = firstResponder.window?.convertToScreen(
            firstResponder.convert(firstResponder.bounds, to: nil)
        ) ?? .zero
        
        showClipboardPanel(at: NSPoint(x: fieldFrame.minX, y: fieldFrame.minY))
    }
    
    private func showClipboardPanel(at location: NSPoint) {
        if clipboardPanel == nil {
            clipboardPanel = ClipboardPanel(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
            clipboardPanel?.selectionDelegate = self
        }
        
        clipboardPanel?.update(with: clipboardManager.getHistory())
        clipboardPanel?.showAtLocation(location)
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let showClipboardPanel = Notification.Name("com.clipboard.showPanel")
}

// MARK: - Protocol Conformance

extension AppDelegate: ClipboardPanelDelegate {
    func clipboardPanel(_ panel: ClipboardPanel, didSelectItem item: ClipboardItem) {
        item.copyToPasteboard()
        clipboardPanel?.close()
    }
}

extension AppDelegate: ClipboardManagerDelegate {
    func clipboardManager(_ manager: ClipboardManager, didUpdateItems items: [ClipboardItem]) {
        clipboardPanel?.update(with: items)
    }
}