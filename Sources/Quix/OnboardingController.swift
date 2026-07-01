import AppKit
import SwiftUI

/// İlk açılış yönlendirme balonunu menü çubuğu ikonunun altında gösterir.
@MainActor
final class OnboardingController {
    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?

    func show(below button: NSStatusBarButton) {
        // Zaten gösteriliyorsa yenile (tekrar-göster durumunda takılı kalmasın)
        dismiss()
        guard let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.frame  // ekran koordinatları

        // İçeriğe göre boyutlan (kırpılma olmasın)
        let hosting = NSHostingController(
            rootView: OnboardingView(onDismiss: { [weak self] in self?.dismiss() })
        )
        hosting.view.layoutSubtreeIfNeeded()
        var size = hosting.view.fittingSize
        if size.width < 50 || size.height < 50 {
            size = NSSize(width: 300, height: 200)   // güvenli varsayılan
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.contentViewController = hosting

        // Konum: ikonun hemen altına ortalı, ekran içinde kalacak şekilde
        var x = buttonFrame.midX - size.width / 2
        let screen = buttonWindow.screen ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            x = min(max(visible.minX + 8, x), visible.maxX - size.width - 8)
        }
        let y = buttonFrame.minY - size.height - 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
        self.panel = panel

        // 9 sn sonra otomatik kapat
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 9, execute: work)
    }

    func dismiss() {
        dismissWork?.cancel()
        dismissWork = nil
        panel?.orderOut(nil)
        panel = nil
    }
}
