// ClaudeCmdEnter — a tiny menu bar helper for the Claude desktop app.
//
//   Enter      -> new line  (Claude receives it as Shift+Enter)
//   Cmd+Enter  -> send      (Claude receives it as plain Enter)
//
// What this program does, and nothing more:
//   * It waits, doing nothing, until the Claude app is opened.
//   * While Claude is running (and the swap is On) it holds a keyboard hook
//     (macOS calls it an "event tap"). The hook only asks one question about
//     each key press: "is this the Return/Enter key, and is Claude in front?"
//   * When Claude quits, the hook and the menu bar item are removed.
//
// It never stores, prints or sends any key. There is no network code.
// The only thing it saves is the On/Off choice (in UserDefaults).

import AppKit

let claudeBundleID = "com.anthropic.claudefordesktop"
let returnKey: Int64 = 36          // the main Return key
let keypadEnterKey: Int64 = 76     // Enter on the number pad (or fn+Return)
let enabledKey = "swapEnabled"     // name of the saved On/Off setting
let accessibilityPane = URL(string:
    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

final class Helper: NSObject, NSMenuDelegate {
    var claudeRunning = false
    var askedForPermission = false     // show the macOS permission prompt only once per run
    var tap: CFMachPort?               // the keyboard hook; nil = no keyboard access at all
    var tapSource: CFRunLoopSource?
    var retryTimer: Timer?             // runs only while we wait for the permission
    var statusItem: NSStatusItem?      // the menu bar item; nil while Claude is closed
    let toggleItem = NSMenuItem(title: "", action: #selector(toggleSwap), keyEquivalent: "")
    let permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    /// The On/Off choice, remembered between launches.
    var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    // MARK: - Watching for Claude

    func start() {
        UserDefaults.standard.register(defaults: [enabledKey: true])   // On by default
        // Ask macOS to tell us when any app opens or quits. This is not keyboard access.
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(self, selector: #selector(appOpenedOrQuit(_:)), name: name, object: nil)
        }
        // Claude may already be open when we start.
        claudeRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: claudeBundleID).isEmpty
        refresh()
    }

    @objc func appOpenedOrQuit(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == claudeBundleID else { return }   // ignore every other app
        let quit = note.name == NSWorkspace.didTerminateApplicationNotification
        claudeRunning = NSRunningApplication
            .runningApplications(withBundleIdentifier: claudeBundleID)
            .contains { !$0.isTerminated && !(quit && $0 == app) }
        refresh()
    }

    /// The single place that decides what should exist right now:
    /// the keyboard hook, the retry timer and the menu bar item.
    @objc func refresh() {
        let trusted = AXIsProcessTrusted()   // has the user granted Accessibility?

        // First time Claude is open without the permission: let macOS show its prompt.
        if claudeRunning && !trusted && !askedForPermission {
            askedForPermission = true
            let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
        }

        // Keyboard hook: only while Claude runs, the swap is On, and we are allowed.
        if claudeRunning && enabled && trusted { startTap() } else { stopTap() }

        // If the hook should exist but does not (permission missing), check again every 2 s.
        let waiting = claudeRunning && enabled && tap == nil
        if waiting && retryTimer == nil {
            retryTimer = Timer.scheduledTimer(timeInterval: 2, target: self,
                selector: #selector(refresh), userInfo: nil, repeats: true)
        } else if !waiting {
            retryTimer?.invalidate()
            retryTimer = nil
        }

        if claudeRunning { showMenuBarItem(trusted: trusted) } else { removeMenuBarItem() }
    }

    // MARK: - The keyboard hook

    func startTap() {
        guard tap == nil else { return }
        // We ask only for key-down and key-up events. No mouse, no text content.
        let keys = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, me in
            Unmanaged<Helper>.fromOpaque(me!).takeUnretainedValue().handle(type, event)
        }
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: keys, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            NSLog("ClaudeCmdEnter: macOS refused the keyboard hook (permission problem)")
            return
        }
        tap = newTap
        tapSource = CFMachPortCreateRunLoopSource(nil, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        NSLog("ClaudeCmdEnter: keyboard hook started")
    }

    func stopTap() {
        guard let oldTap = tap else { return }
        CGEvent.tapEnable(tap: oldTap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes)
        CFMachPortInvalidate(oldTap)      // the hook is now completely gone
        tap = nil
        tapSource = nil
        NSLog("ClaudeCmdEnter: keyboard hook removed")
    }

    /// Called by macOS for every key event while the hook exists.
    /// Returns the event, changed or not. Nothing is kept.
    func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let untouched = Unmanaged.passUnretained(event)

        // macOS can switch a hook off by itself. Switch it back on, unless the
        // permission was taken away: then remove the hook properly.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if AXIsProcessTrusted(), let tap = tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            } else {
                DispatchQueue.main.async { self.refresh() }
            }
            return untouched
        }

        // Any key that is not Return/Enter passes straight through.
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        guard key == returnKey || key == keypadEnterKey else { return untouched }
        // Only when Claude is the app in front. Other apps are never changed.
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == claudeBundleID
        else { return untouched }

        let modifiers = event.flags.intersection(
            [.maskShift, .maskControl, .maskAlternate, .maskCommand])
        if modifiers.isEmpty {
            event.flags.insert(.maskShift)        // Enter      -> Shift+Enter (new line)
        } else if modifiers == .maskCommand {
            event.flags.remove(.maskCommand)      // Cmd+Enter  -> Enter       (send)
        }                                         // Shift+Enter etc. stay as they are
        return untouched
    }

    // MARK: - Menu bar

    func showMenuBarItem(trusted: Bool) {
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let menu = NSMenu()
            menu.delegate = self
            menu.autoenablesItems = false
            toggleItem.target = self
            permissionItem.isEnabled = false      // this line is information only
            let settings = NSMenuItem(title: "Open Accessibility Settings…",
                                      action: #selector(openSettings), keyEquivalent: "")
            let quit = NSMenuItem(title: "Quit ClaudeCmdEnter",
                                  action: #selector(quitHelper), keyEquivalent: "")
            settings.target = self
            quit.target = self
            for entry in [toggleItem, .separator(), permissionItem, settings, .separator(), quit] {
                menu.addItem(entry)
            }
            item.menu = menu
            statusItem = item
        }
        let working = tap != nil
        // Icon:  ⌘↩ = On and working,  ⌘↩ off (grey) = Off,  ⌘↩ ⚠︎ = On but no permission.
        statusItem?.button?.title = !enabled ? "⌘↩ off" : (working ? "⌘↩" : "⌘↩ ⚠︎")
        statusItem?.button?.appearsDisabled = !enabled
        toggleItem.title = enabled ? "On: Enter = new line, ⌘Enter = send"
                                   : "Off: Enter works normally (click to turn On)"
        toggleItem.state = enabled ? .on : .off
        permissionItem.title = !trusted ? "Accessibility permission: NOT granted"
            : (enabled && !working ? "Permission is on but not working: remove it and add it again"
                                   : "Accessibility permission: granted")
    }

    func removeMenuBarItem() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    /// Refresh the texts each time the menu is opened (the permission may have changed).
    func menuNeedsUpdate(_ menu: NSMenu) { refresh() }

    @objc func toggleSwap() { enabled.toggle(); refresh() }
    @objc func openSettings() { NSWorkspace.shared.open(accessibilityPane) }
    @objc func quitHelper() { stopTap(); NSApp.terminate(nil) }
}

// MARK: - Program start

let app = NSApplication.shared
app.setActivationPolicy(.accessory)    // no Dock icon, no main window

// Only one copy may run: two copies would change the same key twice.
if let myID = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: myID)
       .contains(where: { $0 != NSRunningApplication.current }) {
    exit(0)
}

let helper = Helper()
helper.start()
app.run()                              // sleep until macOS has something for us
