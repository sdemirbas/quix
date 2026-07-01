import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let model = RunningAppsModel()
    private let onboarding = OnboardingController()
    private let settings = SettingsController()
    private let updater = UpdaterController()
    private let onboardKey = "didOnboard_v1"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menü çubuğu ikonu — nötr, tek renk (alarm çağrışımı yok)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "rectangle.stack",
                                accessibilityDescription: "Quix")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // Popover + SwiftUI içeriği
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 360, height: 460)
        popover.contentViewController = NSHostingController(
            rootView: RootView(
                model: model,
                onQuitSelf: { NSApp.terminate(nil) },
                onOpenSettings: { [weak self] in self?.openSettings() },
                onCheckForUpdates: { [weak self] in self?.updater.checkForUpdates() }
            )
        )

        // İlk açılışta yönlendirme balonu
        if !UserDefaults.standard.bool(forKey: onboardKey) {
            UserDefaults.standard.set(true, forKey: onboardKey)
            showOnboarding()
        }
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            self.onboarding.show(below: button)
        }
    }

    // MARK: - Ayarlar

    private func openSettings() {
        popover.performClose(nil)
        settings.show(
            model: model,
            onReplayOnboarding: { [weak self] in self?.showOnboarding() },
            onCheckForUpdates: { [weak self] in self?.updater.checkForUpdates() }
        )
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            onboarding.dismiss()
            model.refresh()
            model.startStatsTimer()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            // Popover dışına tıklayınca kapansın diye küçük bir güvence
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // Popover kapanınca timer'ı durdur (CPU tasarrufu) + bekleyen onayı temizle
    func popoverDidClose(_ notification: Notification) {
        model.stopStatsTimer()
        model.cancelPendingQuit()
    }
}
