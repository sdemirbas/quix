import Foundation

/// Hafif iki dilli yardımcı. Sistem dili Türkçe ise TR, değilse EN.
/// (Dil değişimi uygulama yeniden başlatınca geçerli olur — bu tür araçlar için yeterli.)
enum L {
    static let isTurkish: Bool = {
        let pref = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return pref.hasPrefix("tr")
    }()

    /// Türkçe ve İngilizce karşılıkları çağrı yerinde tut.
    static func s(_ tr: String, _ en: String) -> String {
        isTurkish ? tr : en
    }
}
