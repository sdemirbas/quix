import SwiftUI

struct SettingsView: View {
    @Bindable var model: RunningAppsModel
    let onReplayOnboarding: () -> Void
    let onCheckForUpdates: () -> Void

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginFailed = false

    var body: some View {
        Form {
            Section(L.s("Genel", "General")) {
                Toggle(L.s("Oturum açılışında başlat", "Launch at login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        let ok = LoginItem.set(newValue)
                        if !ok {
                            loginFailed = true
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
                if loginFailed {
                    Text(L.s("Bu ayar yalnızca imzalı/Uygulamalar klasöründeki sürümde çalışır.",
                             "This only works in a signed build inside the Applications folder."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(L.s("Hızlandırma Önerileri", "Speedup Suggestions")) {
                VStack(alignment: .leading, spacing: 2) {
                    LabeledContent(L.s("RAM eşiği", "RAM threshold"), value: "\(Int(model.suggestMemoryMB)) MB")
                    Slider(value: $model.suggestMemoryMB, in: 200...4000, step: 50)
                }
                VStack(alignment: .leading, spacing: 2) {
                    LabeledContent(L.s("CPU eşiği", "CPU threshold"), value: "\(Int(model.suggestCPU))%")
                    Slider(value: $model.suggestCPU, in: 5...90, step: 5)
                }
                Text(L.s("Bu eşikleri aşan uygulamalar önerilir. Az önce kullandığın uygulama öneri dışıdır.",
                         "Apps exceeding these thresholds are suggested. The app you just used is excluded."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L.s("Güncellemeler", "Updates")) {
                Button(L.s("Güncellemeleri Denetle…", "Check for Updates…"), action: onCheckForUpdates)
            }

            Section(L.s("Yardım", "Help")) {
                Button(L.s("Karşılama balonunu tekrar göster", "Show welcome tip again"), action: onReplayOnboarding)
            }

            Section {
                LabeledContent(L.s("Sürüm", "Version"), value: "1.0")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 420)
    }
}
