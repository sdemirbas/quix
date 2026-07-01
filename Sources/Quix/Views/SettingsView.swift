import SwiftUI

struct SettingsView: View {
    @Bindable var model: RunningAppsModel
    let onReplayOnboarding: () -> Void
    let onCheckForUpdates: () -> Void

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginFailed = false

    var body: some View {
        Form {
            Section("Genel") {
                Toggle("Oturum açılışında başlat", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        let ok = LoginItem.set(newValue)
                        if !ok {
                            loginFailed = true
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
                if loginFailed {
                    Text("Bu ayar yalnızca imzalı/Uygulamalar klasöründeki sürümde çalışır.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Hızlandırma Önerileri") {
                VStack(alignment: .leading, spacing: 2) {
                    LabeledContent("RAM eşiği", value: "\(Int(model.suggestMemoryMB)) MB")
                    Slider(value: $model.suggestMemoryMB, in: 200...4000, step: 50)
                }
                VStack(alignment: .leading, spacing: 2) {
                    LabeledContent("CPU eşiği", value: "%\(Int(model.suggestCPU))")
                    Slider(value: $model.suggestCPU, in: 5...90, step: 5)
                }
                Text("Bu eşikleri aşan uygulamalar \"sistemi yoruyor\" olarak önerilir. Az önce kullandığın uygulama öneri dışıdır.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Güncellemeler") {
                Button("Güncellemeleri Denetle…", action: onCheckForUpdates)
            }

            Section("Yardım") {
                Button("Karşılama balonunu tekrar göster", action: onReplayOnboarding)
            }

            Section {
                LabeledContent("Sürüm", value: "1.0")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 420)
    }
}
