import Foundation
import Supabase

/// Thin wrapper around Supabase edge functions with a JWT-aware client.
/// SSE streaming uses URLSession.bytes (iOS 15+, async).
@MainActor
final class APIClient {
    static let shared = APIClient()

    private init() {}

    private var supabase: SupabaseClient { SupabaseService.shared.client }

    /// Ephemeral session — disk cache yok, çerez yok. Edge function
    /// response'ları yerelde tutulmaz; "screenshot 24h, conversation 30g"
    /// retention sözünü cihaz tarafında da onurlandırır.
    /// `URLSession.shared` default cache (Caches/Cache.db) ile çelişiyordu.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    // ──────────────────────────────────────────────────────────
    // JSON request → JSON response
    // ──────────────────────────────────────────────────────────

    func invokeJSON<Response: Decodable>(
        _ endpoint: Endpoint,
        body: Encodable? = nil,
        as: Response.Type = Response.self,
    ) async throws -> Response {
        let token = try await accessToken()

        let url = Configuration.supabaseURL.appendingPathComponent("functions/v1/\(endpoint.rawValue)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(Configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")

        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await APIClient.session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown("invalid response")
        }

        if http.statusCode >= 400 {
            throw try mapError(data: data, status: http.statusCode)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    // ──────────────────────────────────────────────────────────
    // Multipart upload (parse-screenshot)
    // ──────────────────────────────────────────────────────────

    func invokeMultipart<Response: Decodable>(
        _ endpoint: Endpoint,
        imageData: Data?,
        imageMimeType: String = "image/jpeg",
        formFields: [String: String] = [:],
        as: Response.Type = Response.self,
    ) async throws -> Response {
        let token = try await accessToken()
        let url = Configuration.supabaseURL.appendingPathComponent("functions/v1/\(endpoint.rawValue)")

        let boundary = "----EfsoBoundary\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(Configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")

        var body = Data()
        let crlf = "\r\n"

        for (k, v) in formFields {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(k)\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(v.data(using: .utf8)!)
            body.append(crlf.data(using: .utf8)!)
        }

        // Image dosyası opsiyonel — manuel giriş akışında nil gelir, sadece
        // form fields gönderilir (manual_input JSON içinde).
        if let imageData {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"screenshot\"; filename=\"screenshot.jpg\"\(crlf)".data(using: .utf8)!)
            body.append("Content-Type: \(imageMimeType)\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(imageData)
            body.append(crlf.data(using: .utf8)!)
        }
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)

        req.httpBody = body

        let (respData, response) = try await APIClient.session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown("invalid response")
        }
        if http.statusCode >= 400 {
            throw try mapError(data: respData, status: http.statusCode)
        }
        return try JSONDecoder().decode(Response.self, from: respData)
    }

    // ──────────────────────────────────────────────────────────
    // SSE stream (generate-replies)
    // ──────────────────────────────────────────────────────────

    /// Multipart upload + SSE stream. Used by the v2 unified `generate`
    /// endpoint so screenshot/manual input and generation happen in one call.
    func invokeMultipartStream(
        _ endpoint: Endpoint,
        imageData: Data?,
        imageMimeType: String = "image/jpeg",
        formFields: [String: String] = [:],
    ) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let innerTask = Task {
                do {
                    let token = try await accessToken()
                    let url = Configuration.supabaseURL.appendingPathComponent("functions/v1/\(endpoint.rawValue)")
                    let boundary = "----EfsoBoundary\(UUID().uuidString)"
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    req.setValue(Configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")

                    var body = Data()
                    let crlf = "\r\n"
                    for (k, v) in formFields {
                        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
                        body.append("Content-Disposition: form-data; name=\"\(k)\"\(crlf)\(crlf)".data(using: .utf8)!)
                        body.append(v.data(using: .utf8)!)
                        body.append(crlf.data(using: .utf8)!)
                    }
                    if let imageData {
                        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
                        body.append("Content-Disposition: form-data; name=\"screenshot\"; filename=\"screenshot.jpg\"\(crlf)".data(using: .utf8)!)
                        body.append("Content-Type: \(imageMimeType)\(crlf)\(crlf)".data(using: .utf8)!)
                        body.append(imageData)
                        body.append(crlf.data(using: .utf8)!)
                    }
                    body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
                    req.httpBody = body

                    try await streamSSE(req, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in innerTask.cancel() }
        }
    }

    /// Yields parsed SSE events from a POST body.
    /// Caller pattern-matches on `SSEEvent`.
    func invokeStream(
        _ endpoint: Endpoint,
        body: Encodable,
    ) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let innerTask = Task {
                do {
                    let token = try await accessToken()
                    let url = Configuration.supabaseURL.appendingPathComponent("functions/v1/\(endpoint.rawValue)")
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    req.setValue(Configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
                    req.httpBody = try JSONEncoder().encode(AnyEncodable(body))

                    try await streamSSE(req, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in innerTask.cancel() }
        }
    }

    // ──────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────

    private func accessToken() async throws -> String {
        // Anon key fallback kaldırıldı — Bearer token olarak kullanılmamalı.
        // Session yoksa çağrı yapılamaz; bootstrap sırasında anon user oluşur.
        let session = try await supabase.auth.session
        return session.accessToken
    }

    private func mapError(data: Data, status: Int) throws -> APIError {
        if let body = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            return APIError.map(body)
        }
        let raw = String(data: data, encoding: .utf8) ?? ""
        return .server(code: "http_\(status)", message: raw.isEmpty ? "HTTP \(status)" : raw)
    }

    private func streamSSE(
        _ req: URLRequest,
        continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation,
    ) async throws {
        let (bytes, response) = try await APIClient.session.bytes(for: req)
        guard let http = response as? HTTPURLResponse else {
            continuation.finish(throwing: APIError.unknown("invalid response"))
            return
        }
        if http.statusCode >= 400 {
            var data = Data()
            for try await b in bytes { data.append(b) }
            continuation.finish(throwing: try mapError(data: data, status: http.statusCode))
            return
        }

        var watchdog: Task<Void, Never>?
        func resetWatchdog() {
            watchdog?.cancel()
            watchdog = Task {
                try? await Task.sleep(for: .seconds(30))
                if !Task.isCancelled {
                    continuation.finish(throwing: APIError.unknown("üretim zaman aşımı"))
                }
            }
        }
        resetWatchdog()
        defer { watchdog?.cancel() }

        for try await line in bytes.lines {
            resetWatchdog()
            if line.isEmpty { continue }
            if line.hasPrefix("data:") {
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if payload.isEmpty || payload == "[DONE]" { continue }
                if let data = payload.data(using: .utf8),
                   let event = try? JSONDecoder().decode(SSEEvent.self, from: data) {
                    continuation.yield(event)
                    if case .done = event { break }
                }
            }
        }
        continuation.finish()
    }
}

// MARK: - SSE event model

enum SSEEvent: Decodable, Sendable {
    case parseSummary(platform: String, screenshotType: String, context: String)
    case observation(text: String)
    case reply(index: Int, tone: String, text: String)
    /// `remaining_today`: free user için kalan üretim (server-truth).
    /// Premium ise nil (sınırsız). Client quota chip bunu kullanır.
    case done(durationMs: Int, conversationId: String, remainingToday: Int?, remainingRefinesToday: Int?, isPremium: Bool)
    case error(message: String)
    case unknown

    private enum CodingKeys: String, CodingKey {
        case type, text, index, tone
        case platform, context
        case screenshotType = "screenshot_type"
        case durationMs = "duration_ms"
        case conversationId = "conversation_id"
        case remainingToday = "remaining_today"
        case remainingRefinesToday = "remaining_refines_today"
        case isPremium = "is_premium"
        case message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? c.decode(String.self, forKey: .type)) ?? ""
        switch type {
        case "parse_summary":
            let platform = (try? c.decode(String.self, forKey: .platform)) ?? "unknown"
            let screenshotType = (try? c.decode(String.self, forKey: .screenshotType)) ?? ""
            let context = (try? c.decode(String.self, forKey: .context)) ?? ""
            self = .parseSummary(platform: platform, screenshotType: screenshotType, context: context)
        case "observation":
            let text = (try? c.decode(String.self, forKey: .text)) ?? ""
            self = .observation(text: text)
        case "reply":
            let index = (try? c.decode(Int.self, forKey: .index)) ?? 0
            let tone = (try? c.decode(String.self, forKey: .tone)) ?? ""
            let text = (try? c.decode(String.self, forKey: .text)) ?? ""
            self = .reply(index: index, tone: tone, text: text)
        case "done":
            let ms = (try? c.decode(Int.self, forKey: .durationMs)) ?? 0
            let id = (try? c.decode(String.self, forKey: .conversationId)) ?? ""
            let remaining = (try? c.decodeIfPresent(Int.self, forKey: .remainingToday)) ?? nil
            let remainingRefines = (try? c.decodeIfPresent(Int.self, forKey: .remainingRefinesToday)) ?? nil
            let prem = (try? c.decodeIfPresent(Bool.self, forKey: .isPremium)) ?? false
            self = .done(durationMs: ms, conversationId: id, remainingToday: remaining, remainingRefinesToday: remainingRefines, isPremium: prem)
        case "error":
            let msg = (try? c.decode(String.self, forKey: .message)) ?? ""
            self = .error(message: msg)
        default:
            self = .unknown
        }
    }
}

// MARK: - AnyEncodable helper

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
