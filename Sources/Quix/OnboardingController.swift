import AppKit
import SwiftUI

/// İlk açılış yönlendirme balonunu menü çubuğu ikonunun altında gösterir.
@MainActor
final class OnboardingController {
    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?

    private let width: CGFloat = 290
    private let height: CGFloat = 155

    func show(below button: NSStatusBarButton) {
        guard panel == nil, let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.frame  // ekran koordinatları

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
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

        let root = OnboardingView(onDismiss: { [weak self] in self?.dismiss() })
        panel.contentViewController = NSHostingController(rootView: root)

        // Konum: ikonun hemen altına ortalı, ekran içinde kalacak şekilde
        var x = buttonFrame.midX - width / 2
        let screen = buttonWindow.screen ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            x = min(max(visible.minX + 8, x), visible.maxX - width - 8)
        }
        let y = buttonFrame.minY - height - 2
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
