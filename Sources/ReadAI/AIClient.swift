import Foundation

struct AIClient {
    let apiKey: String
    let baseURL: String
    let model: String

    func answer(question: String, context: String) async throws -> String {
        let endpoint = normalizedBaseURL().appendingPathComponent("responses")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        You are a reading assistant. Answer in the user's language. Use the provided book excerpt when relevant.

        Book excerpt:
        \(context.isEmpty ? "(No excerpt available.)" : context)

        Question:
        \(question)
        """

        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "input": prompt
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ReadAIError("No response from AI service.")
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = parseError(data) ?? "AI request failed: HTTP \(http.statusCode)."
            throw ReadAIError(message)
        }

        if let text = parseOutputText(data), !text.isEmpty {
            return text
        }
        throw ReadAIError("AI response had no text.")
    }

    private func normalizedBaseURL() -> URL {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: trimmed) ?? URL(string: "https://api.openai.com/v1")!
    }

    private func parseOutputText(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let outputText = json["output_text"] as? String {
            return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let output = json["output"] as? [[String: Any]] else { return nil }
        let pieces = output.flatMap { item -> [String] in
            guard let content = item["content"] as? [[String: Any]] else { return [] }
            return content.compactMap { part in
                part["text"] as? String
            }
        }

        return pieces.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseError(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }

        if let error = json["error"] as? [String: Any] {
            return (error["message"] as? String) ?? String(describing: error)
        }
        return String(data: data, encoding: .utf8)
    }
}
