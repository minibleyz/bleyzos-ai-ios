import Foundation

enum APIClientError: LocalizedError {
    case invalidURL
    case httpError(Int, String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg ?? "ошибка")"
        case .decodingError(let err): return "Ошибка декодирования: \(err.localizedDescription)"
        case .networkError(let err): return "Сеть: \(err.localizedDescription)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
    }

    // MARK: - Generic POST (JSON)

    func post<T: Decodable>(url: String, body: [String: Any]) async throws -> T {
        guard let requestURL = URL(string: url) else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            try checkHTTPResponse(response, data: data)
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIClientError.decodingError(error)
            }
        } catch let error as APIClientError {
            throw error
        } catch {
            throw APIClientError.networkError(error)
        }
    }

    // MARK: - Streaming POST (NDJSON)

    func streamChat(
        url: String,
        messages: [[String: String]],
        session: String,
        files: [String: Data]? = nil
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let requestURL = URL(string: url) else {
                        continuation.finish(throwing: APIClientError.invalidURL)
                        return
                    }

                    var request = URLRequest(url: requestURL)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 120

                    if let files, !files.isEmpty {
                        // Multipart form data
                        let boundary = "Boundary-\(UUID().uuidString)"
                        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

                        var body = Data()
                        // messages
                        let messagesJSON = try JSONSerialization.data(withJSONObject: messages)
                        body.append("--\(boundary)\r\n".data(using: .utf8)!)
                        body.append("Content-Disposition: form-data; name=\"messages\"\r\n\r\n".data(using: .utf8)!)
                        body.append(messagesJSON)
                        body.append("\r\n".data(using: .utf8)!)
                        // session
                        body.append("--\(boundary)\r\n".data(using: .utf8)!)
                        body.append("Content-Disposition: form-data; name=\"session\"\r\n\r\n".data(using: .utf8)!)
                        body.append(session.data(using: .utf8)!)
                        body.append("\r\n".data(using: .utf8)!)
                        // files
                        for (filename, fileData) in files {
                            body.append("--\(boundary)\r\n".data(using: .utf8)!)
                            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
                            body.append(fileData)
                            body.append("\r\n".data(using: .utf8)!)
                        }
                        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                        request.httpBody = body
                    } else {
                        // JSON
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        let payload: [String: Any] = [
                            "messages": messages,
                            "session": session,
                        ]
                        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                    }

                    let (bytes, response) = try await session.bytes(for: request)
                    try checkHTTPResponse(response, data: nil)

                    var buffer = ""
                    for try await line in bytes.lines {
                        buffer += line
                        let parts = buffer.components(separatedBy: "\n")
                        buffer = parts.last ?? ""

                        for part in parts.dropLast() {
                            let trimmed = part.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty,
                                  let data = trimmed.data(using: .utf8),
                                  let event = try? decoder.decode(StreamEvent.self, from: data)
                            else { continue }

                            continuation.yield(event)

                            if case .done = event {
                                continuation.finish()
                                return
                            }
                        }
                    }

                    // Process remaining buffer
                    if !buffer.trimmingCharacters(in: .whitespaces).isEmpty,
                       let data = buffer.data(using: .utf8),
                       let event = try? decoder.decode(StreamEvent.self, from: data) {
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Helpers

    private func checkHTTPResponse(_ response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = data.flatMap { String(data: $0, encoding: .utf8) }
            throw APIClientError.httpError(http.statusCode, body)
        }
    }
}
