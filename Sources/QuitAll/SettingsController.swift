import AppKit
import SwiftUI

/// Ayarlar penceresini (tek örnek) yönetir. Accessory uygulama olduğundan
/// pencere öne getirilirken uygulama geçici olarak aktive edilir.
@MainActor
final class SettingsController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(onReplayOnboarding: @escaping () -> Void,
              onCheckForUpdates: @escaping () -> Void) {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(
            rootView: SettingsView(
                onReplayOnboarding: onReplayOnboarding,
                onCheckForUpdates: onCheckForUpdates
            )
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "QuitAll Ayarları"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
