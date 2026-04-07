import Foundation

struct AITask: Sendable {
    let title: String
    let tag: TaskPriorityTag
}

struct AIResult: Sendable {
    let tasks: [AITask]
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
        let l = AppLanguageStore.shared
        switch self {
        case .missingAPIKey:
            return l.localized("ai.error.missing_api_key")
        case .invalidResponse:
            return l.localized("ai.error.invalid_response")
        case let .network(error):
            return l.localizedFormat("ai.error.network", error.localizedDescription as NSString)
        case let .requestFailed(statusCode, message):
            if let message, !message.isEmpty {
                return l.localizedFormat("ai.error.request_failed_detail", statusCode, message as NSString)
            }

            return l.localizedFormat("ai.error.request_failed_status", statusCode)
        case .malformedJSON:
            return l.localized("ai.error.malformed_json")
        }
    }
}

enum AIResponseParser {
    private struct TaskPayload: Decodable {
        let title: String
        let tag: String?
    }

    private struct DecodedResponse: Decodable {
        private enum CodingKeys: String, CodingKey {
            case tasks
            case ideas
            case notes
        }

        let tasks: [AITask]
        let ideas: [String]
        let notes: [String]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            ideas = try container.decodeIfPresent([String].self, forKey: .ideas) ?? []
            notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []

            if container.contains(.tasks) {
                if let payloads = try? container.decode([TaskPayload].self, forKey: .tasks) {
                    tasks = sanitizeAITasks(payloads.map { payload in
                        AITask(title: payload.title, tag: TaskPriorityTag.from(aiString: payload.tag ?? ""))
                    })
                } else if let strings = try? container.decode([String].self, forKey: .tasks) {
                    tasks = sanitizeAITasks(strings.map { AITask(title: $0, tag: .important) })
                } else {
                    tasks = []
                }
            } else {
                tasks = []
            }
        }
    }

    static func parse(json: String) throws -> AIResult {
        let cleaned = normalize(json: json)
        let data = Data(cleaned.utf8)

        if let decoded = try? JSONDecoder().decode(DecodedResponse.self, from: data) {
            return AIResult(
                tasks: decoded.tasks,
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
            tasks: parseTasksArray(object["tasks"]),
            ideas: sanitize(object["ideas"] as? [String] ?? []),
            notes: sanitize(object["notes"] as? [String] ?? [])
        )
    }

    private static func sanitizeAITasks(_ tasks: [AITask]) -> [AITask] {
        tasks
            .map { AITask(title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines), tag: $0.tag) }
            .filter { !$0.title.isEmpty }
    }

    private static func parseTasksArray(_ value: Any?) -> [AITask] {
        guard let array = value as? [Any] else { return [] }
        var result: [AITask] = []
        for item in array {
            if let str = item as? String {
                let title = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    result.append(AITask(title: title, tag: .important))
                }
            } else if let dict = item as? [String: Any] {
                let title = (dict["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { continue }
                let tagString = dict["tag"] as? String ?? ""
                result.append(AITask(title: title, tag: TaskPriorityTag.from(aiString: tagString)))
            }
        }
        return result
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
