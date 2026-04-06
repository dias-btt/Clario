import Foundation

struct AIResult: Sendable {
    let tasks: [String]
    let ideas: [String]
    let notes: [String]

    static let empty = AIResult(tasks: [], ideas: [], notes: [])
}

protocol AIService: Sendable {
    func process(input: String) async throws -> AIResult
}

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case network(Error)
    case requestFailed(statusCode: Int, message: String?)
    case malformedJSON

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key не найден. Добавьте `OPENAI_API_KEY` в environment variables или `Info.plist`."
        case .invalidResponse:
            return "OpenAI вернул неожиданный ответ."
        case let .network(error):
            return "Ошибка сети: \(error.localizedDescription)"
        case let .requestFailed(statusCode, message):
            if let message, !message.isEmpty {
                return "OpenAI error \(statusCode): \(message)"
            }

            return "OpenAI request failed with status \(statusCode)."
        case .malformedJSON:
            return "Не удалось распарсить JSON от AI."
        }
    }
}

enum AIResponseParser {
    private struct DecodedResponse: Decodable {
        private enum CodingKeys: String, CodingKey {
            case tasks
            case ideas
            case notes
        }

        let tasks: [String]
        let ideas: [String]
        let notes: [String]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tasks = try container.decodeIfPresent([String].self, forKey: .tasks) ?? []
            ideas = try container.decodeIfPresent([String].self, forKey: .ideas) ?? []
            notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []
        }
    }

    static func parse(json: String) throws -> AIResult {
        let cleaned = normalize(json: json)
        let data = Data(cleaned.utf8)

        if let decoded = try? JSONDecoder().decode(DecodedResponse.self, from: data) {
            return AIResult(
                tasks: sanitize(decoded.tasks),
                ideas: sanitize(decoded.ideas),
                notes: sanitize(decoded.notes)
            )
        }

        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw AIServiceError.malformedJSON
        }

        return AIResult(
            tasks: sanitize(object["tasks"] as? [String] ?? []),
            ideas: sanitize(object["ideas"] as? [String] ?? []),
            notes: sanitize(object["notes"] as? [String] ?? [])
        )
    }

    private static func sanitize(_ values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func normalize(json: String) -> String {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            let withoutFenceMarker = trimmed
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let jsonSlice = extractJSONObject(from: withoutFenceMarker) {
                return jsonSlice
            }

            return withoutFenceMarker
        }

        if let jsonSlice = extractJSONObject(from: trimmed) {
            return jsonSlice
        }

        return trimmed
    }

    private static func extractJSONObject(from text: String) -> String? {
        guard
            let start = text.firstIndex(of: "{"),
            let end = text.lastIndex(of: "}")
        else {
            return nil
        }

        return String(text[start...end])
    }
}
