import Foundation

struct OpenAIService: AIService {
    private let apiKey: String
    private let model: String
    private let session: URLSession
    private let endpoint: URL

    init(
        apiKey: String,
        model: String = "gpt-4.1",
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.endpoint = endpoint
    }

    static func live(
        apiKey: String? = nil,
        model: String = "gpt-4.1",
        session: URLSession = .shared
    ) -> OpenAIService {
        OpenAIService(
            apiKey: apiKey ?? RuntimeOpenAIConfiguration.apiKey,
            model: model,
            session: session
        )
    }

    func process(input: String) async throws -> AIResult {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return .empty }

        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")

        let payload = OpenAIChatCompletionRequest(
            model: model,
            messages: [
                .init(role: "system", content: PromptBuilder.systemPrompt),
                .init(role: "user", content: PromptBuilder.userPrompt(for: trimmedInput))
            ]
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIServiceError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data).error.message
            throw AIServiceError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let completion: OpenAIChatCompletionResponse

        do {
            completion = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
        } catch {
            throw AIServiceError.invalidResponse
        }

        guard let content = completion.choices.first?.message.content, !content.isEmpty else {
            throw AIServiceError.invalidResponse
        }

        return try AIResponseParser.parse(json: content)
    }

    func summarizeDailyDigest(structuredContext: String, languageCode: String) async throws -> String {
        let trimmedContext = structuredContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContext.isEmpty else {
            throw AIServiceError.invalidResponse
        }

        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        let languageName = Self.digestLanguageName(for: languageCode)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")

        let payload = OpenAIDigestChatRequest(
            model: model,
            messages: [
                .init(
                    role: "system",
                    content: Self.digestSystemPrompt(languageName: languageName)
                ),
                .init(
                    role: "user",
                    content: Self.digestUserPrompt(context: trimmedContext, languageName: languageName)
                )
            ]
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIServiceError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data).error.message
            throw AIServiceError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let completion: OpenAIChatCompletionResponse

        do {
            completion = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
        } catch {
            throw AIServiceError.invalidResponse
        }

        guard let raw = completion.choices.first?.message.content else {
            throw AIServiceError.invalidResponse
        }

        let summary = Self.stripDigestFences(from: raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !summary.isEmpty else {
            throw AIServiceError.invalidResponse
        }

        return summary
    }

    private static func digestLanguageName(for code: String) -> String {
        switch code.lowercased() {
        case "ru": return "Russian"
        case "kk": return "Kazakh"
        default: return "English"
        }
    }

    private static func digestSystemPrompt(languageName: String) -> String {
        """
        You write short daily digests for a productivity app called Clario.
        Output 2–4 sentences of plain prose only. No markdown, no bullet lists, no title line, no emojis.
        Tone: calm, clear, and spacious—especially for people who overthink. Acknowledge priorities gently without hype.
        Write entirely in \(languageName).
        """
    }

    private static func digestUserPrompt(context: String, languageName: String) -> String {
        """
        Use the following snapshot from the user's data (tasks for today are listed urgent-first). \
        Compose a digest in \(languageName).

        \(context)
        """
    }

    private static func stripDigestFences(from text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```markdown", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }
}

private struct OpenAIDigestChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature = 0.45
    let maxTokens = 220

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private enum RuntimeOpenAIConfiguration {
    static var apiKey: String {
        if let environmentKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !environmentKey.isEmpty {
            return environmentKey
        }

        if let infoPlistKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !infoPlistKey.isEmpty {
            return infoPlistKey
        }

        return ""
    }
}

private enum PromptBuilder {
    static let systemPrompt = """
    You are an AI assistant inside a SwiftUI productivity app called Second Brain.
    Your job is to convert raw brain-dump text into structured JSON.

    Rules:
    - Return valid JSON only.
    - Do not include markdown, code fences, commentary, or explanation.
    - Output exactly these keys: tasks, ideas, notes.
    - tasks must be an array of objects, each with: title (string) and tag (string).
    - tag must be exactly one of: urgent, important, low_priority (infer urgency from wording and deadlines).
    - ideas and notes must be arrays of strings.
    - Tasks must be actionable, concise, and phrased as standalone actions.
    - Ideas are concepts to explore, not immediate action items.
    - Notes are factual thoughts, reflections, or information that do not fit tasks or ideas.
    - Preserve the user's original language when possible.
    - Remove duplicates and empty items.
    - Keep each item short, clear, and clean for direct app display.
    """

    static func userPrompt(for input: String) -> String {
        """
        Convert the following raw thought dump into structured JSON.

        Required JSON shape:
        {
          "tasks": [ { "title": String, "tag": "urgent" | "important" | "low_priority" } ],
          "ideas": [String],
          "notes": [String]
        }

        Raw input:
        \(input)
        """
    }
}

private struct OpenAIChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature = 0.2
    let responseFormat = ResponseFormat.jsonSchema

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }

    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
        let jsonSchema: JSONSchema

        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }

        static let jsonSchema = ResponseFormat(
            type: "json_schema",
            jsonSchema: JSONSchema(
                name: "second_brain_result",
                strict: true,
                schema: Schema()
            )
        )
    }

    struct JSONSchema: Encodable {
        let name: String
        let strict: Bool
        let schema: Schema
    }

    struct Schema: Encodable {
        let type = "object"
        let properties = Properties()
        let required = ["tasks", "ideas", "notes"]
        let additionalProperties = false
    }

    struct Properties: Encodable {
        let tasks = TaskItemsArrayField()
        let ideas = ArrayField()
        let notes = ArrayField()
    }

    struct TaskItemsArrayField: Encodable {
        let type = "array"
        let items = TaskObjectSchema()
    }

    struct TaskObjectSchema: Encodable {
        let type = "object"
        let properties = TaskObjectProperties()
        let required = ["title", "tag"]
        let additionalProperties = false
    }

    struct TaskObjectProperties: Encodable {
        let title = StringField()
        let tag = TagEnumField()
    }

    struct TagEnumField: Encodable {
        let type = "string"
        let enumValues = ["urgent", "important", "low_priority"]

        enum CodingKeys: String, CodingKey {
            case type
            case enumValues = "enum"
        }
    }

    struct ArrayField: Encodable {
        let type = "array"
        let items = StringField()
    }

    struct StringField: Encodable {
        let type = "string"
    }
}

private struct OpenAIChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    let error: OpenAIAPIError

    struct OpenAIAPIError: Decodable {
        let message: String
    }
}
