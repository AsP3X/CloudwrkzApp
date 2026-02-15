//
//  SearchService.swift
//  Cloudwrkz
//
//  Fetches results from GET /api/search or GET /api/auth/search. Uses Bearer token and ServerConfig.
//

import Foundation

enum SearchServiceError: Equatable, Error {
    case noServerURL
    case noToken
    case unauthorized
    case serverError(message: String)
    case networkError(description: String)
}

enum SearchService {
    private static let timeout: TimeInterval = 15

    private static func searchPathSegments(loginPath: String) -> [String] {
        let path = loginPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchPath = path.isEmpty ? "api/search" : path.replacingOccurrences(of: "login", with: "search", options: .caseInsensitive)
        return searchPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    /// GET /api/search?q=...&limit=20 (or /api/auth/search when using auth login path).
    static func search(config: ServerConfig, query: String, limit: Int = 20) async -> Result<SearchResponse, SearchServiceError> {
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

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.serverError(message: "Invalid response"))
            }
            switch http.statusCode {
            case 200:
                let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
                return .success(decoded)
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
            return .failure(.networkError(description: error.localizedDescription))
        }
    }
}

private struct MessageResponse: Decodable {
    let message: String?
}
