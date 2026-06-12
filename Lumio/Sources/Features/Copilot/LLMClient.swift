import Foundation
import os

private let logger = Logger(subsystem: "app.lumio.Lumio", category: "LLM")

// Copilot answers are meant to be spoken, so they're short; a tight cap also
// keeps streaming snappy during live calls.
let llmMaxTokens = 512

enum CopilotBackend: String, CaseIterable {
    case anthropic
    case openai
}

struct LLMMessage {
    enum Role: String { case user, assistant }
    let role: Role
    let content: String
}

enum LLMError: LocalizedError {
    case missingAPIKey
    case invalidBaseURL
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "API key is not configured"
        case .invalidBaseURL: "Invalid endpoint URL"
        case .http(let code, let body): "HTTP \(code): \(body)"
        }
    }
}

protocol LLMClient: Sendable {
    func stream(messages: [LLMMessage], system: String) -> AsyncThrowingStream<String, Error>
}

// Reads "data: {...}" SSE lines and surfaces each JSON payload string.
private func sseDataLines(
    _ bytes: URLSession.AsyncBytes
) -> AsyncCompactMapSequence<AsyncLineSequence<URLSession.AsyncBytes>, String> {
    bytes.lines.compactMap { line in
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst(6))
        return payload == "[DONE]" ? nil : payload
    }
}

private func parseSSEObject(_ payload: String) -> [String: Any]? {
    do {
        return try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any]
    } catch {
        logger.warning("skipping malformed SSE chunk: \(error.localizedDescription, privacy: .public)")
        return nil
    }
}

private func validate(_ response: URLResponse, firstBytes bytes: URLSession.AsyncBytes) async throws {
    guard let http = response as? HTTPURLResponse, http.statusCode != 200 else { return }
    var body = ""
    for try await line in bytes.lines {
        body += line
        if body.count > 500 { break }
    }
    throw LLMError.http((response as? HTTPURLResponse)?.statusCode ?? -1, body)
}

struct AnthropicClient: LLMClient {
    static let endpoint = "https://api.anthropic.com/v1/messages"
    static let apiVersion = "2023-06-01"

    let apiKey: String
    let model: String

    func stream(messages: [LLMMessage], system: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }
                    guard let url = URL(string: Self.endpoint) else { throw LLMError.invalidBaseURL }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: [
                        "model": model,
                        "max_tokens": llmMaxTokens,
                        "stream": true,
                        "system": system,
                        "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
                    ])

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try await validate(response, firstBytes: bytes)

                    for try await payload in sseDataLines(bytes) {
                        guard
                            let json = parseSSEObject(payload),
                            json["type"] as? String == "content_block_delta",
                            let delta = json["delta"] as? [String: Any],
                            let text = delta["text"] as? String
                        else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

struct OpenAICompatibleClient: LLMClient {
    let apiKey: String
    let model: String
    let baseURL: String

    func stream(messages: [LLMMessage], system: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }
                    let trimmed = baseURL.trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    guard let url = URL(string: "\(trimmed)/v1/chat/completions") else {
                        throw LLMError.invalidBaseURL
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    var chat: [[String: String]] = [["role": "system", "content": system]]
                    chat += messages.map { ["role": $0.role.rawValue, "content": $0.content] }
                    request.httpBody = try JSONSerialization.data(withJSONObject: [
                        "model": model,
                        "max_tokens": llmMaxTokens,
                        "stream": true,
                        "messages": chat,
                    ])

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try await validate(response, firstBytes: bytes)

                    for try await payload in sseDataLines(bytes) {
                        guard
                            let json = parseSSEObject(payload),
                            let choices = json["choices"] as? [[String: Any]],
                            let delta = choices.first?["delta"] as? [String: Any],
                            let text = delta["content"] as? String
                        else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum LLMClientFactory {
    @MainActor
    static func make() -> LLMClient {
        let settings = AppSettings.shared
        switch settings.copilotBackend {
        case .anthropic:
            return AnthropicClient(
                apiKey: KeychainStore.get("anthropicAPIKey") ?? "",
                model: settings.copilotModel.isEmpty ? "claude-haiku-4-5-20251001" : settings.copilotModel
            )
        case .openai:
            return OpenAICompatibleClient(
                apiKey: KeychainStore.get("openaiAPIKey") ?? "",
                model: settings.copilotModel,
                baseURL: settings.copilotBaseURL
            )
        }
    }
}
