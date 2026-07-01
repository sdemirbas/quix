import SwiftUI

struct AppRowView: View {
    @Bindable var model: RunningAppsModel
    let app: AppInfo
    var selected: Bool = false

    @State private var hovering = false

    private var optionHeld: Bool { model.optionHeld }
    private var isSuggested: Bool { model.isSuggested(app) }
    private var isActive: Bool { model.isActive(app) }

    var body: some View {
        HStack(spacing: 10) {
            iconView

            HStack(spacing: 5) {
                Text(app.name)
                    .lineLimit(1)
                if isActive {
                    Text("aktif")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .accessibilityLabel("Aktif uygulama")
                }
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
                .fill(background)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name), \(app.memoryText)")
        .contextMenu { contextMenu }
    }

    private var background: Color {
        if selected { return Color.accentColor.opacity(0.22) }
        if hovering { return Color.primary.opacity(0.08) }
        return .clear
    }

    // Sağ taraf: bilgi gürültüsü yok — detay hover'da açığa çıkar, sadece aykırılar işaretli.
    @ViewBuilder
    private var trailing: some View {
        if hovering || selected {
            HStack(spacing: 8) {
                Text(app.memoryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                quitButton
            }
        } else if isSuggested {
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
        Button {
            model.quit(app)
        } label: {
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
        .accessibilityLabel(optionHeld ? "\(app.name) uygulamasını zorla kapat" : "\(app.name) uygulamasını kapat")
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Kapat") { model.quit(app) }
        Button("Zorla Kapat") { model.forceQuit(app) }
        Divider()
        Button(app.runningApp.isHidden ? "Göster" : "Gizle") { model.toggleHide(app) }
        Button("Finder'da Göster") { model.revealInFinder(app) }
        Divider()
        Button("Diğerlerini Kapat…") { model.requestQuitOthers(app) }
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
