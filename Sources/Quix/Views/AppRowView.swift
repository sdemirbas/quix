import SwiftUI

struct AppRowView: View {
    let app: AppInfo
    let optionHeld: Bool
    let isSuggested: Bool
    let onQuit: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            iconView

            HStack(spacing: 5) {
                Text(app.name)
                    .lineLimit(1)
                if app.isMenuBarApp {
                    Image(systemName: "menubar.arrow.up.rectangle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .help("Menü çubuğu uygulaması")
                }
            }

            Spacer(minLength: 8)

            trailing
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Color.primary.opacity(0.08) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    // Sağ taraf: bilgi gürültüsü yok — detay hover'da açığa çıkar, sadece aykırılar işaretli.
    @ViewBuilder
    private var trailing: some View {
        if hovering {
            HStack(spacing: 8) {
                Text(app.memoryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                quitButton
            }
        } else if isSuggested {
            // Hızlandırma önerisi: çok kaynak tüketiyor
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.orange)
                Text(app.memoryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } else if app.isHighUsage {
            // "Önemli enerji kullanıyor" göstergesi
            HStack(spacing: 4) {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                Text(app.cpuText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var quitButton: some View {
        Button(action: onQuit) {
            Image(systemName: optionHeld ? "bolt.fill" : "xmark")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 20, height: 20)
                .background(
                    Circle().fill(optionHeld
                                  ? Color.red.opacity(0.9)
                                  : Color.primary.opacity(0.12))
                )
                .foregroundStyle(optionHeld ? Color.white : Color.primary)
        }
        .buttonStyle(.borderless)
        .help(optionHeld ? "Zorla kapat" : "Kapat")
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
        }
    }
}
