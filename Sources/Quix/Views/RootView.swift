import SwiftUI

struct RootView: View {
    @Bindable var model: RunningAppsModel
    let onQuitSelf: () -> Void
    let onRequestQuitAll: (_ force: Bool, _ count: Int) -> Void
    let onOpenSettings: () -> Void
    let onCheckForUpdates: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            categoryPicker
            Divider().opacity(0.5)
            appList
            Divider().opacity(0.5)
            footer
        }
        .frame(width: 360, height: 460)
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
                        AppRowView(app: app, optionHeld: model.optionHeld) {
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
                onRequestQuitAll(model.optionHeld, model.filteredApps.count)
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
