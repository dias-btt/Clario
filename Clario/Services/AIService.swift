import Foundation

struct BrainParseResult: Sendable {
    let tasks: [String]
    let ideas: [String]
    let notes: [String]

    static let empty = BrainParseResult(tasks: [], ideas: [], notes: [])
}

protocol AIService: Sendable {
    func process(input: String) async throws -> BrainParseResult
}

enum AIServiceError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Не удалось обработать ответ AI."
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

    static func parse(json: String) throws -> BrainParseResult {
        let data = Data(json.utf8)

        if let decoded = try? JSONDecoder().decode(DecodedResponse.self, from: data) {
            return BrainParseResult(
                tasks: sanitize(decoded.tasks),
                ideas: sanitize(decoded.ideas),
                notes: sanitize(decoded.notes)
            )
        }

        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw AIServiceError.invalidResponse
        }

        return BrainParseResult(
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
}
