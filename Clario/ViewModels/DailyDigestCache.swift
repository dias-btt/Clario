import Foundation

/// Persists the last daily digest summary keyed by a stable content fingerprint.
struct DailyDigestCache {
    private static let fingerprintKey = "dailyDigest.cache.fingerprint.sha256"
    private static let summaryKey = "dailyDigest.cache.summary"

    static let standard = DailyDigestCache(defaults: .standard)

    private let defaults: UserDefaults

    /// Pass an isolated `UserDefaults` suite in tests.
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func summary(forFingerprint fingerprint: String) -> String? {
        guard defaults.string(forKey: Self.fingerprintKey) == fingerprint else {
            return nil
        }
        let text = defaults.string(forKey: Self.summaryKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    func store(_ summary: String, fingerprint: String) {
        defaults.set(fingerprint, forKey: Self.fingerprintKey)
        defaults.set(summary, forKey: Self.summaryKey)
    }
}
