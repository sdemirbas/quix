import Foundation
import ServiceManagement

/// Oturum açılışında başlatma (SMAppService). Ad-hoc/imzasız bundle'da
/// hata verebilir; bu durumda sessizce loglanır.
@MainActor
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("LoginItem ayarlanamadı: \(error.localizedDescription)")
            return false
        }
    }
}
