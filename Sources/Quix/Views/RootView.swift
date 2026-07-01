import SwiftUI

struct RootView: View {
    @Bindable var model: RunningAppsModel
    let onQuitSelf: () -> Void
    let onOpenSettings: () -> Void
    let onCheckForUpdates: () -> Void

    @State private var selectedID: pid_t?
    @FocusState private var searchFocused: Bool

    private var selectedApp: AppInfo? {
        model.filteredApps.first { $0.id == selectedID }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                searchBar
                categoryPicker
                if !model.suggestions.isEmpty {
                    suggestionsBanner
                }
                Divider().opacity(0.5)
                appList
                Divider().opacity(0.5)
                footer
            }

            if let pending = model.pendingQuit {
                ConfirmQuitView(
                    pending: pending,
                    force: model.optionHeld,
                    onConfirm: { model.confirmPendingQuit() },
                    onCancel: { model.cancelPendingQuit() }
                )
                .transition(.opacity)
            }
        }
        .frame(width: 360, height: 460)
        .animation(.easeOut(duration: 0.15), value: model.pendingQuit?.id)
        .onAppear { DispatchQueue.main.async { searchFocused = true } }
        .onKeyPress(action: handleKey)
    }

    // MARK: - Klavye

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if model.pendingQuit != nil { return .ignored }
        switch press.key {
        case .downArrow: moveSelection(1); return .handled
        case .upArrow:   moveSelection(-1); return .handled
        case .escape:
            if !model.searchText.isEmpty { model.searchText = ""; return .handled }
            if selectedID != nil { selectedID = nil; return .handled }
            return .ignored
        default:
            if press.modifiers.contains(.command) {
                if press.characters == "w", let app = selectedApp {
                    model.quit(app); return .handled
                }
                if press.characters == "f" { searchFocused = true; return .handled }
            }
            return .ignored
        }
    }

    private func moveSelection(_ delta: Int) {
        let list = model.filteredApps
        guard !list.isEmpty else { return }
        if let id = selectedID, let idx = list.firstIndex(where: { $0.id == id }) {
            let next = min(max(idx + delta, 0), list.count - 1)
            selectedID = list[next].id
        } else {
            selectedID = delta > 0 ? list.first?.id : list.last?.id
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(Color.accentColor)
            Text("Quix")
                .font(.headline)
            if model.optionHeld {
                Text("FORCE")
                    .font(.caption2).bold()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            }
            Spacer()
            Menu {
                Picker(L.s("Sırala", "Sort"), selection: $model.sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(L.s("Sırala: ", "Sort: ") + model.sortOrder.label)
            .accessibilityLabel(L.s("Sıralama ölçütü", "Sort order"))

            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help(L.s("Yenile", "Refresh"))
            .accessibilityLabel(L.s("Listeyi yenile", "Refresh list"))
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L.s("Uygulama ara…", "Search apps…"), text: $model.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    // MARK: - Category

    private var categoryPicker: some View {
        Picker(L.s("Kategori", "Category"), selection: $model.category) {
            ForEach(AppCategory.allCases) { cat in
                Text("\(cat.label) (\(model.count(for: cat)))").tag(cat)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Hızlandırma önerisi

    private var suggestionsBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 16, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(L.isTurkish
                     ? "\(model.suggestions.count) uygulama sistemi yoruyor"
                     : "\(model.suggestions.count) app\(model.suggestions.count == 1 ? "" : "s") straining your system")
                    .font(.subheadline).fontWeight(.semibold)
                Text(L.s("~\(model.reclaimableText) RAM boşaltabilirsin",
                         "Free up ~\(model.reclaimableText) RAM"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.requestQuitSuggested()
            } label: {
                Text(model.optionHeld ? L.s("Zorla", "Force") : L.s("Kapat", "Quit"))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.orange)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: - List

    private var appList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if model.filteredApps.isEmpty {
                        ContentUnavailableView(
                            model.searchText.isEmpty
                                ? L.s("Çalışan uygulama yok", "No running apps")
                                : L.s("Sonuç bulunamadı", "No results"),
                            systemImage: model.searchText.isEmpty ? "checkmark.circle" : "magnifyingglass"
                        )
                        .padding(.vertical, 24)
                    } else {
                        ForEach(model.filteredApps) { app in
                            AppRowView(model: model, app: app, selected: app.id == selectedID)
                                .id(app.id)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .animation(.easeInOut(duration: 0.25), value: model.filteredApps.map(\.id))
            }
            .frame(maxHeight: .infinity)
            .onChange(of: selectedID) { _, id in
                if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Text(L.isTurkish
                 ? "\(model.filteredApps.count) uygulama · \(model.totalMemoryText)"
                 : "\(model.filteredApps.count) app\(model.filteredApps.count == 1 ? "" : "s") · \(model.totalMemoryText)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            Button {
                model.requestQuitAll()
            } label: {
                Text(model.optionHeld ? L.s("Hepsini Zorla Kapat", "Force Quit All")
                                      : L.s("Hepsini Kapat", "Quit All"))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(model.optionHeld ? .red : .secondary)
            .disabled(model.filteredApps.isEmpty)

            Menu {
                Button(L.s("Güncellemeleri Denetle…", "Check for Updates…"), action: onCheckForUpdates)
                Button(L.s("Ayarlar…", "Settings…"), action: onOpenSettings)
                Divider()
                Button(L.s("Quix'ten Çık", "Quit Quix"), role: .destructive, action: onQuitSelf)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
