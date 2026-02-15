//
//  AuthService.swift
//  Cloudwrkz
//
//  Login API client. Matches References/cloudwrkz when available.
//
//  API contract:
//  - Endpoint: POST {baseURL}/api/login (or configurable via ServerConfig.loginPath)
//  - Request body: { "email": string, "password": string }
//  - Success (200): { "token": string } or { "accessToken": string, "refreshToken"?: string }
//  - Error (401/4xx/5xx): { "message"?: string } or similar
//

import Foundation

// MARK: - Request / Response types

private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

/// Success response from POST /api/auth/login (References/cloudwrkz).
/// Supports both "token" and "accessToken" for backend flexibility.
private struct LoginSuccessResponse: Decodable {
    let token: String?
    let accessToken: String?

    var storedToken: String? {
        token ?? accessToken
    }
}

/// Error body from login endpoint when status is 4xx/5xx.
/// Supports common shapes: message, error, detail, msg; or errors[].
private struct LoginErrorResponse: Decodable {
    let message: String?
    let error: String?
    let detail: String?
    let msg: String?
    let errors: [String]?

    /// First non-empty string from any supported field.
    var displayMessage: String? {
        if let m = message, !m.isEmpty { return m }
        if let m = error, !m.isEmpty { return m }
        if let m = detail, !m.isEmpty { return m }
        if let m = msg, !m.isEmpty { return m }
        if let arr = errors, let first = arr.first(where: { !$0.isEmpty }) { return first }
        return nil
    }
}

// MARK: - Result type

enum AuthLoginFailure: Equatable, Error {
    case noServerURL
    case invalidCredentials
    case serverError(message: String)
    case networkError(description: String)
}

enum AuthService {
    private static let timeout: TimeInterval = 15

    /// Performs POST baseURL/{config.loginPath}. Does not store the token; caller must use AuthTokenStorage.
    static func login(email: String, password: String, config: ServerConfig) async -> Result<String, AuthLoginFailure> {
        guard let base = config.baseURL else {
            return .failure(.noServerURL)
        }
        let path = config.loginPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathToUse = path.isEmpty ? ServerConfig.defaultLoginPath : path
        let pathSegments = pathToUse
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard !pathSegments.isEmpty else {
            return .failure(.noServerURL)
        }
        var url = base
        for segment in pathSegments {
            url = url.appending(path: segment)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = LoginRequest(email: email, password: password)
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return .failure(.networkError(description: error.localizedDescription))
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.serverError(message: "Invalid response"))
            }

            switch http.statusCode {
            case 200...299:
                let decoded = try JSONDecoder().decode(LoginSuccessResponse.self, from: data)
                guard let token = decoded.storedToken, !token.isEmpty else {
                    return .failure(.serverError(message: "No token in response"))
                }
                return .success(token)
            case 401:
                return .failure(.invalidCredentials)
            case 400...599:
                let message = extractServerErrorMessage(data: data, statusCode: http.statusCode, requestURL: request.url)
                return .failure(.serverError(message: message))
            default:
                return .failure(.serverError(message: "Unexpected status \(http.statusCode)"))
            }
        } catch {
            let description = (error as? URLError)?.localizedDescription ?? error.localizedDescription
            return .failure(.networkError(description: description))
        }
    }

    /// Extracts a user-visible message from 4xx/5xx response body, or returns a fallback including status code.
    private static func extractServerErrorMessage(data: Data, statusCode: Int, requestURL: URL? = nil) -> String {
        if let errorBody = try? JSONDecoder().decode(LoginErrorResponse.self, from: data),
           let msg = errorBody.displayMessage, !msg.isEmpty {
            return msg
        }
        var fallback: String
        if !data.isEmpty, let raw = String(data: data, encoding: .utf8) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if isHTML(trimmed) {
                    if let title = extractHTMLTitle(trimmed), !title.isEmpty {
                        fallback = "Server error (\(statusCode)): \(title)"
                    } else {
                        fallback = "Server error (\(statusCode)). The server returned a web page instead of a JSON response."
                    }
                } else {
                    fallback = trimmed.count <= 200 ? trimmed : String(trimmed.prefix(197)) + "..."
                }
            } else {
                fallback = "Server error (\(statusCode))"
            }
        } else {
            fallback = "Server error (\(statusCode))"
        }
        if statusCode == 404, let url = requestURL {
            fallback += " No route at: \(url.absoluteString)"
        }
        return fallback
    }

    private static func isHTML(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.hasPrefix("<!doctype") || lower.hasPrefix("<html") || lower.contains("</html>")
    }

    private static func extractHTMLTitle(_ html: String) -> String? {
        guard let start = html.range(of: "<title", options: .caseInsensitive),
              let endOpen = html[start.upperBound...].range(of: ">"),
              let endClose = html[endOpen.upperBound...].range(of: "</title>", options: .caseInsensitive) else {
            return nil
        }
        let content = String(html[endOpen.upperBound..<endClose.lowerBound])
        return content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
}
