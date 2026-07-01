import SwiftUI

struct SettingsView: View {
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
        .frame(width: 380, height: 260)
    }
}
