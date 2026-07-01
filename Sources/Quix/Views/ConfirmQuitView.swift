import SwiftUI

/// Popover içi toplu kapatma onayı — hangi uygulamaların kapatılacağını listeler.
struct ConfirmQuitView: View {
    let pending: PendingQuit
    let force: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            // Arka planı karart, dışına tıklayınca vazgeç
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(systemName: force ? "bolt.trianglebadge.exclamationmark.fill" : "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(force ? .red : .orange)
                    Text(L.isTurkish
                         ? "\(pending.apps.count) uygulama kapatılacak"
                         : "\(pending.apps.count) app\(pending.apps.count == 1 ? "" : "s") will quit")
                        .font(.headline)
                }

                // Kapatılacak uygulamaların listesi
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(pending.apps) { app in
                            HStack(spacing: 8) {
                                if let icon = app.icon {
                                    Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                                }
                                Text(app.name).lineLimit(1)
                                Spacer()
                                Text(app.memoryText)
                                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 190)

                Text(force
                     ? L.s("Zorla kapatma kaydedilmemiş değişiklikleri kaybettirir.",
                           "Force quitting will discard unsaved changes.")
                     : L.s("Kaydedilmemiş değişiklikler için uygulamalar sana soracak; verin korunur.",
                           "Apps with unsaved changes will ask you; your data is safe."))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button(L.s("Vazgeç", "Cancel"), action: onCancel)
                        .controlSize(.large)
                    Button(force ? L.s("Zorla Kapat", "Force Quit") : L.s("Kapat", "Quit"),
                           role: .destructive, action: onConfirm)
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .tint(force ? .red : .accentColor)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(width: 300)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.quaternary))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 6)
        }
    }
}
