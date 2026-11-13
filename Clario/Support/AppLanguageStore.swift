import Foundation
import Observation

@Observable
final class AppLanguageStore {
    static let shared = AppLanguageStore()

    private static let storageKey = "app.preferred.language.code"
    private static let supportedCodes: Set<String> = ["en", "ru", "kk"]
    private static let fallbackCode = "en"

    var code: String {
        didSet {
            UserDefaults.standard.set(code, forKey: Self.storageKey)
        }
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.storageKey),
           Self.supportedCodes.contains(stored) {
            code = stored
            return
        }
        let system = Locale.current.language.languageCode?.identifier ?? Self.fallbackCode
        code = Self.supportedCodes.contains(system) ? system : Self.fallbackCode
    }

    func localized(_ key: String) -> String {
        Self.localized(key, languageCode: code)
    }

    func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        Self.localizedFormat(key, languageCode: code, arguments: arguments)
    }

    /// Localizes `key` for an explicit language code (no dependency on the shared, persisted selection).
    static func localized(_ key: String, languageCode: String) -> String {
        bundle(for: languageCode).localizedString(forKey: key, value: nil, table: nil)
    }

    static func localizedFormat(_ key: String, languageCode: String, arguments: [CVarArg]) -> String {
        let format = localized(key, languageCode: languageCode)
        return String(format: format, locale: Locale(identifier: languageCode), arguments: arguments)
    }

    private static func bundle(for code: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
