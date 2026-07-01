import SwiftUI

/// İlk açılışta menü çubuğu ikonuna yönlendiren balon.
/// "Reduce Motion" açıksa hareket yerine sabit gösterim yapar.
struct OnboardingView: View {
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "chevron.up")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.tint)
                .opacity(reduceMotion ? 1 : (animate ? 1 : 0.35))
                .offset(y: reduceMotion ? 0 : (animate ? -3 : 1))
                .animation(
                    reduceMotion ? nil
                    : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                    value: animate
                )

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.stack")
                        .foregroundStyle(.tint)
                    Text("Quix hazır")
                        .font(.headline)
                }
                Text("Çalışan uygulamaları görüp kapatmak için\nyukarıdaki menü çubuğu ikonuna tıkla.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Anladım", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.quaternary)
            )
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
        .padding(8)
        .onAppear { animate = true }
    }
}
