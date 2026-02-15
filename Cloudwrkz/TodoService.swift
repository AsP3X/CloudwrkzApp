//
//  TodoService.swift
//  Cloudwrkz
//
//  Fetches todos from GET /api/todos. Uses Bearer token and ServerConfig.
//

import Foundation

enum TodoServiceError: Equatable, Error {
    case noServerURL
    case noToken
    case unauthorized
    case serverError(message: String)
    case networkError(description: String)
}

enum TodoService {
    private static let timeout: TimeInterval = 20

    /// Path for GET todos: derived from login path (api/auth/login → api/auth/todos, api/login → api/todos).
    private static func todosPathSegments(loginPath: String) -> [String] {
        let path = loginPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let todosPath = path.isEmpty ? "api/todos" : path.replacingOccurrences(of: "login", with: "todos", options: .caseInsensitive)
        return todosPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    private static var dateDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: s) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date: \(s)")
        }
        return d
    }

    /// GET /api/todos with optional query params. Returns todos or error.
    static func fetchTodos(config: ServerConfig, filters: TodoFilters) async -> Result<[Todo], TodoServiceError> {
        guard let base = config.baseURL else {
            return .failure(.noServerURL)
        }
        guard let token = AuthTokenStorage.getToken(), !token.isEmpty else {
            return .failure(.noToken)
        }
        let pathSegments = todosPathSegments(loginPath: config.loginPath)
        guard !pathSegments.isEmpty else {
            return .failure(.noServerURL)
        }
        var url = base
        for segment in pathSegments {
            url = url.appending(path: segment)
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "status", value: filters.status.rawValue))
        queryItems.append(URLQueryItem(name: "priority", value: filters.priority.rawValue))
        queryItems.append(URLQueryItem(name: "sort", value: filters.sort.rawValue))
        queryItems.append(URLQueryItem(name: "archive", value: filters.archive.rawValue))
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let finalURL = components.url else {
            return .failure(.noServerURL)
        }
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.serverError(message: "Invalid response"))
            }
            switch http.statusCode {
            case 200:
                let decoded = try dateDecoder.decode(TodosResponse.self, from: data)
                return .success(decoded.todos)
            case 401:
                return .failure(.unauthorized)
            case 400...599:
                let message = (try? JSONDecoder().decode(MessageResponse.self, from: data))?.message
                    ?? "Server error (\(http.statusCode))"
                return .failure(.serverError(message: message))
            default:
                return .failure(.serverError(message: "Unexpected status \(http.statusCode)"))
            }
        } catch {
            let description = (error as? URLError)?.localizedDescription ?? error.localizedDescription
            return .failure(.networkError(description: description))
        }
    }

    private static func isoDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

private struct MessageResponse: Decodable {
    let message: String?
}
