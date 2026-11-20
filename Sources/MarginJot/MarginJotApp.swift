import AppKit
import SwiftUI

@main
@MainActor
enum MarginJotApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let note = Note()
    private let focus = EditorFocus()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 340, height: 260)
        popover.contentViewController = NSHostingController(
            rootView: NoteView(note: note, focus: focus, dismiss: { [weak self] in
                self?.popover.performClose(nil)
            })
        )

        guard let button = statusItem.button else { return }
        let icon = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Jot")
        icon?.isTemplate = true
        button.image = icon
        button.toolTip = "Jot"
        button.setAccessibilityLabel("Jot")
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func togglePopover(_ button: NSStatusBarButton) {
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp ||
           (event.type == .leftMouseUp && event.modifierFlags.contains(.control)) {
            popover.performClose(button)
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit Jot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            let bottom = button.isFlipped ? button.bounds.maxY : button.bounds.minY
            menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.minX, y: bottom), in: button)
            return
        }
        if popover.isShown {
            popover.performClose(button)
        } else {
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            focus.makeFirstResponder()
        }
    }

    func popoverDidShow(_ notification: Notification) {
        focus.makeFirstResponder()
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Jot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        return mainMenu
    }
}
