import Foundation
import Sparkle

/// Sparkle otomatik güncelleme sarmalayıcısı.
/// Besleme URL'si ve açık anahtar Info.plist'ten okunur (SUFeedURL, SUPublicEDKey).
@MainActor
final class UpdaterController {
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Kullanıcı tetikli güncelleme denetimi.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
}
