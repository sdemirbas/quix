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
                    Text(L.s("aktif", "active"))
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .accessibilityLabel(L.s("Aktif uygulama", "Active app"))
                }
                if app.isMenuBarApp {
                    Image(systemName: "menubar.arrow.up.rectangle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .help(L.s("Menü çubuğu uygulaması", "Menu bar app"))
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
        .help(optionHeld ? L.s("Zorla kapat", "Force quit") : L.s("Kapat", "Quit"))
        .accessibilityLabel(
            optionHeld ? L.s("\(app.name) uygulamasını zorla kapat", "Force quit \(app.name)")
                       : L.s("\(app.name) uygulamasını kapat", "Quit \(app.name)")
        )
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button(L.s("Kapat", "Quit")) { model.quit(app) }
        Button(L.s("Zorla Kapat", "Force Quit")) { model.forceQuit(app) }
        Divider()
        Button(app.runningApp.isHidden ? L.s("Göster", "Show") : L.s("Gizle", "Hide")) { model.toggleHide(app) }
        Button(L.s("Finder'da Göster", "Reveal in Finder")) { model.revealInFinder(app) }
        Divider()
        Button(L.s("Diğerlerini Kapat…", "Quit Others…")) { model.requestQuitOthers(app) }
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
