import Foundation

/// Persists the last daily digest summary keyed by a stable content fingerprint.
enum DailyDigestCache {
    private static let fingerprintKey = "dailyDigest.cache.fingerprint.sha256"
    private static let summaryKey = "dailyDigest.cache.summary"

    static func summary(forFingerprint fingerprint: String) -> String? {
        guard UserDefaults.standard.string(forKey: fingerprintKey) == fingerprint else {
            return nil
        }
        let text = UserDefaults.standard.string(forKey: summaryKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    static func store(_ summary: String, fingerprint: String) {
        UserDefaults.standard.set(fingerprint, forKey: fingerprintKey)
        UserDefaults.standard.set(summary, forKey: summaryKey)
    }
}
