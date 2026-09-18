import Foundation
import os

enum APIClientError: LocalizedError {
    case invalidURL
    case httpError(Int, String?)
    case decodingError(Error)
    case networkError(Error)
    case timeout(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg ?? "ошибка")"
        case .decodingError(let err): return "Ошибка декодирования: \(err.localizedDescription)"
        case .networkError(let err): return "Сеть: \(err.localizedDescription)"
        case .timeout(let seconds): return "сервер не присылает данные уже \(seconds) с"
        case .emptyResponse: return "сервер закрыл соединение, не прислав ни одного события"
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private static let log = Logger(subsystem: "ru.bleyzos.ai", category: "stream")

    /// Сколько секунд стрим может молчать (нет ни одного нового байта), прежде чем
    /// мы считаем соединение зависшим и показываем ошибку. Это таймаут НЕАКТИВНОСТИ
    /// (сбрасывается на каждый полученный байт), а не общий лимит на ответ.
    /// Было 24 часа — из-за этого зависший запрос никогда не заканчивался ошибкой.
    static let streamIdleTimeout: TimeInterval = 180

    private let session: URLSession
    // Отдельная сессия для стриминга чата: сервер может молчать долго
    // (облачная модель, очередь tool-раундов) прежде чем прислать
    // следующий чанк NDJSON, поэтому общего лимита на длительность нет, только
    // лимит на бездействие (см. streamIdleTimeout).
    private let streamSession: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)

        let streamConfig = URLSessionConfiguration.default
        streamConfig.timeoutIntervalForRequest = Self.streamIdleTimeout
        streamConfig.timeoutIntervalForResource = 6 * 60 * 60
        self.streamSession = URLSession(configuration: streamConfig)

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
        sessionId: String,
        files: [String: Data]? = nil
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let requestURL = URL(string: url) else {
                        continuation.finish(throwing: APIClientError.invalidURL)
                        return
                    }

                    var request = URLRequest(url: requestURL)
                    request.httpMethod = "POST"
                    request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
                    // Своего таймаута на запрос не ставим - границы заданы
                    // конфигом streamSession (см. init).

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
                        body.append(sessionId.data(using: .utf8)!)
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
                            "session": sessionId,
                        ]
                        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                    }

                    let startedAt = Date()
                    let (bytes, response) = try await streamSession.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    Self.log.info("stream: HTTP \(status) через \(Date().timeIntervalSince(startedAt), format: .fixed(precision: 2)) с")

                    // Не-2xx: читаем начало тела ошибки, чтобы показать причину, а не «HTTP 502».
                    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                        var errorBody = Data()
                        for try await byte in bytes {
                            errorBody.append(byte)
                            if errorBody.count >= 500 { break }
                        }
                        throw APIClientError.httpError(http.statusCode, String(data: errorBody, encoding: .utf8))
                    }

                    // bytes.lines уже отдаёт готовые, очищенные от "\n" строки -
                    // сервер шлёт ровно один JSON-объект на строку (NDJSON).
                    var received = 0
                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { continue }

                        let event: StreamEvent
                        do {
                            event = try decoder.decode(StreamEvent.self, from: data)
                        } catch {
                            Self.log.warning("stream: не разобрана строка: \(String(trimmed.prefix(200)))")
                            continue
                        }

                        received += 1
                        if received == 1 {
                            Self.log.info("stream: первое событие через \(Date().timeIntervalSince(startedAt), format: .fixed(precision: 2)) с")
                        }
                        continuation.yield(event)

                        if case .done = event {
                            continuation.finish()
                            return
                        }
                    }

                    if received == 0 {
                        throw APIClientError.emptyResponse
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let urlError as URLError where urlError.code == .cancelled {
                    continuation.finish()
                } catch let urlError as URLError where urlError.code == .timedOut {
                    Self.log.error("stream: таймаут неактивности")
                    continuation.finish(throwing: APIClientError.timeout(Int(Self.streamIdleTimeout)))
                } catch {
                    Self.log.error("stream: ошибка \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            // Главное: когда потребитель отменил/бросил стрим («Стоп», новый чат, смена
            // сессии), отменяем и внутреннюю Task — иначе соединение остаётся открытым
            // и накапливается; после нескольких таких «сирот» новые запросы упираются
            // в лимит соединений на хост и висят без ошибки.
            continuation.onTermination = { _ in task.cancel() }
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
