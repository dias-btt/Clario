import Foundation

struct MockAIService: AIService {
    func process(input: String) async throws -> BrainParseResult {
        try await Task.sleep(for: .milliseconds(900))

        let response = buildMockJSON(from: input)
        return try AIResponseParser.parse(json: response)
    }

    private func buildMockJSON(from input: String) -> String {
        let fragments = input
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if fragments.isEmpty {
            return """
            {
              "tasks": [],
              "ideas": [],
              "notes": []
            }
            """
        }

        var tasks: [String] = []
        var ideas: [String] = []
        var notes: [String] = []

        for fragment in fragments {
            let lowered = fragment.lowercased()

            if lowered.contains("todo")
                || lowered.contains("нужно")
                || lowered.contains("надо")
                || lowered.contains("сделать")
                || lowered.contains("buy")
                || lowered.contains("send")
                || lowered.contains("call") {
                tasks.append(clean(fragment))
            } else if lowered.contains("idea")
                || lowered.contains("explore")
                || lowered.contains("maybe")
                || lowered.contains("could")
                || lowered.contains("хочу")
                || lowered.contains("иде")
                || lowered.contains("попробовать") {
                ideas.append(clean(fragment))
            } else {
                notes.append(clean(fragment))
            }
        }

        if tasks.isEmpty, let first = notes.first {
            tasks.append("Follow up: \(first)")
        }

        let payload = MockPayload(tasks: tasks, ideas: ideas, notes: notes)
        let data = try? JSONEncoder().encode(payload)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{\"tasks\":[],\"ideas\":[],\"notes\":[]}"
    }

    private func clean(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
    }
}

private struct MockPayload: Encodable {
    let tasks: [String]
    let ideas: [String]
    let notes: [String]
}
