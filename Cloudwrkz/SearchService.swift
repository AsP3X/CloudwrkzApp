//
//  SearchService.swift
//  Cloudwrkz
//
//  Fetches results from GET /api/search or GET /api/auth/search. Uses Bearer token and ServerConfig.
//  Cancels in-flight requests when a new search starts.
//

import Foundation

enum SearchServiceError: Equatable, Error {
    case noServerURL
    case noToken
    case unauthorized
    case serverError(message: String)
    case networkError(description: String)
    case cancelled
}

enum SearchService {
    private static let timeout: TimeInterval = 15
    private static var currentTask: URLSessionDataTask?

    private static func searchPathSegments(loginPath: String) -> [String] {
        let path = loginPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchPath = path.isEmpty ? "api/search" : path.replacingOccurrences(of: "login", with: "search", options: .caseInsensitive)
        return searchPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    /// GET /api/search?q=...&limit=20 (or /api/auth/search when using auth login path). Cancels previous request if still in flight.
    static func search(config: ServerConfig, query: String, limit: Int = 20) async -> Result<SearchResponse, SearchServiceError> {
        currentTask?.cancel()
        currentTask = nil

        guard let base = config.baseURL else {
            return .failure(.noServerURL)
        }
        guard let token = AuthTokenStorage.getToken(), !token.isEmpty else {
            return .failure(.noToken)
        }
        let pathSegments = searchPathSegments(loginPath: config.loginPath)
        guard !pathSegments.isEmpty else {
            return .failure(.noServerURL)
        }
        var url = base
        for segment in pathSegments {
            url = url.appending(path: segment)
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let finalURL = components.url else {
            return .failure(.noServerURL)
        }
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                defer { currentTask = nil }
                if let error = error as? URLError, error.code == .cancelled {
                    continuation.resume(returning: .failure(.cancelled))
                    return
                }
                if let error = error {
                    continuation.resume(returning: .failure(.networkError(description: error.localizedDescription)))
                    return
                }
                guard let data = data, let http = response as? HTTPURLResponse else {
                    continuation.resume(returning: .failure(.serverError(message: "Invalid response")))
                    return
                }
                switch http.statusCode {
                case 200:
                    do {
                        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
                        continuation.resume(returning: .success(decoded))
                    } catch {
                        continuation.resume(returning: .failure(.networkError(description: error.localizedDescription)))
                    }
                case 401:
                    continuation.resume(returning: .failure(.unauthorized))
                case 400...599:
                    let message = (try? JSONDecoder().decode(MessageResponse.self, from: data))?.message
                        ?? "Server error (\(http.statusCode))"
                    continuation.resume(returning: .failure(.serverError(message: message)))
                default:
                    continuation.resume(returning: .failure(.serverError(message: "Unexpected status \(http.statusCode)")))
                }
            }
            currentTask = task
            task.resume()
        }
    }
}

private struct MessageResponse: Decodable {
    let message: String?
}
