import AppKit
import SwiftUI
import Combine
import LyricCore

final class FloatingWindow: NSWindow {
    var didDrag = false
    var onCompactClick: (() -> Void)?
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown { didDrag = false }
        super.sendEvent(event)
        // Native window dragging runs its tracking loop inside mouseDown.
        // Keep the compact shape after a drag; a normal click restores controls.
        if event.type == .leftMouseDown && !didDrag { onCompactClick?() }
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel: FloatingWindow!
    private var expandedSize = NSSize(width: 480, height: 610)
    private var focusRevision = 0
    private var anchor: WindowAnchor = .topLeft
    private var isChangingMode = false
    var model: PlayerModel!
    var pinObserver: AnyCancellable?
    func applicationDidFinishLaunching(_ notification: Notification) {
        model = PlayerModel()
        if ProcessInfo.processInfo.arguments.contains("--demo") { model.source = .demo }
        panel = FloatingWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 610), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        panel.title = "LyricFloat"
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        panel.onCompactClick = { [weak self] in self?.setCompact(false) }
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 380, height: 380)
        panel.backgroundColor = NSColor(calibratedRed: 0.075, green: 0.086, blue: 0.095, alpha: 1)
        let hostingView = NSHostingView(rootView: PlayerView(model: model))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.setFrameAutosaveName("LyricFloatWindow")
        panel.center()
        pinObserver = model.$pinned.sink { [weak self] pinned in self?.panel.level = pinned ? .floating : .normal }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let menu = NSMenu()
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit LyricFloat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let item = NSMenuItem(); item.submenu = appMenu; menu.addItem(item)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); editItem.submenu = edit; menu.addItem(editItem)
        NSApp.mainMenu = menu
    }
    func windowDidBecomeKey(_ notification: Notification) {
        focusRevision += 1
        // The click handler decides whether this is a click or a drag.
        if NSApp.currentEvent?.type != .leftMouseDown { setCompact(false) }
    }
    func windowWillMove(_ notification: Notification) {
        guard panel.attachedSheet == nil, !model.showSetup, !model.showSearch else { return }
        panel.didDrag = true
        setCompact(true)
    }
    func windowDidMove(_ notification: Notification) {
        guard !isChangingMode, panel.didDrag, let screen = placementScreen else { return }
        // Only a user's move chooses a new corner. Expansion must keep that choice.
        anchor = WindowAnchor.nearest(to: panel.frame, on: screen)
    }
    private var placementScreen: NSRect? {
        NSScreen.screens.max { a, b in
            let first = a.visibleFrame.intersection(panel.frame)
            let second = b.visibleFrame.intersection(panel.frame)
            return first.width * first.height < second.width * second.height
        }?.visibleFrame ?? panel.screen?.visibleFrame
    }
    func windowDidResignKey(_ notification: Notification) {
        focusRevision += 1
        let revision = focusRevision
        // Menus and sheets temporarily take focus; let AppKit finish that transition first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.focusRevision == revision, !self.panel.isKeyWindow,
                  self.panel.attachedSheet == nil, !self.model.showSetup, !self.model.showSearch,
                  self.model.errorMessage == nil, self.panel.isVisible else { return }
            self.setCompact(true)
        }
    }
    func applicationDidResignActive(_ notification: Notification) {
        guard panel.attachedSheet == nil, !model.showSetup, !model.showSearch, model.errorMessage == nil else { return }
        setCompact(true)
    }
    private func setCompact(_ compact: Bool) {
        guard model.isCompact != compact else { return }
        let oldFrame = panel.frame
        if compact { expandedSize = oldFrame.size }
        isChangingMode = true
        defer { isChangingMode = false }
        // Keep the chosen screen corner fixed through both size transitions.
        let size = compact ? NSSize(width: min(420, max(320, oldFrame.width)), height: 210) : expandedSize
        panel.minSize = compact ? NSSize(width: 320, height: 180) : NSSize(width: 380, height: 380)
        // Normal content starts below the native title bar; compact glass fills the window.
        if compact { panel.styleMask.insert(.fullSizeContentView) }
        else { panel.styleMask.remove(.fullSizeContentView) }
        panel.titlebarAppearsTransparent = compact
        panel.isOpaque = !compact
        panel.backgroundColor = compact ? .clear : NSColor(calibratedRed: 0.075, green: 0.086, blue: 0.095, alpha: 1)
        model.isCompact = compact
        panel.standardWindowButton(.closeButton)?.isHidden = compact
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = compact
        panel.standardWindowButton(.zoomButton)?.isHidden = compact
        let frame = anchor.resized(oldFrame, to: size, within: placementScreen)
        panel.setFrame(frame, display: true, animate: false)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.deminiaturize(nil)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setCompact(false)
        return true
    }
    // A closed window is recoverable from the Dock; only Quit ends playback monitoring.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
