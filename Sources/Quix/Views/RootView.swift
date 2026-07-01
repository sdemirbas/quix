import SwiftUI

struct RootView: View {
    @Bindable var model: RunningAppsModel
    let onQuitSelf: () -> Void
    let onOpenSettings: () -> Void
    let onCheckForUpdates: () -> Void

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
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.stack")
                .foregroundStyle(.secondary)
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
                Picker("Sırala", selection: $model.sortOrder) {
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
            .help("Sırala: \(model.sortOrder.label)")

            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Yenile")
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
            TextField("Uygulama ara…", text: $model.searchText)
                .textFieldStyle(.plain)
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
        Picker("Kategori", selection: $model.category) {
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
                Text("\(model.suggestions.count) uygulama sistemi yoruyor")
                    .font(.subheadline).fontWeight(.semibold)
                Text("~\(model.reclaimableText) RAM boşaltabilirsin")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.requestQuitSuggested()
            } label: {
                Text(model.optionHeld ? "Zorla" : "Kapat")
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
        ScrollView {
            LazyVStack(spacing: 2) {
                if model.filteredApps.isEmpty {
                    ContentUnavailableView(
                        model.searchText.isEmpty ? "Çalışan uygulama yok" : "Sonuç bulunamadı",
                        systemImage: model.searchText.isEmpty ? "checkmark.circle" : "magnifyingglass"
                    )
                    .padding(.vertical, 24)
                } else {
                    ForEach(model.filteredApps) { app in
                        AppRowView(app: app,
                                   optionHeld: model.optionHeld,
                                   isSuggested: model.isSuggested(app)) {
                            model.quit(app)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Text("\(model.filteredApps.count) uygulama")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                model.requestQuitAll()
            } label: {
                Text(model.optionHeld ? "Hepsini Zorla Kapat" : "Hepsini Kapat")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(model.optionHeld ? .red : .secondary)
            .disabled(model.filteredApps.isEmpty)

            Menu {
                Button("Güncellemeleri Denetle…", action: onCheckForUpdates)
                Button("Ayarlar…", action: onOpenSettings)
                Divider()
                Button("Quix'ten Çık", role: .destructive, action: onQuitSelf)
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
