//
//  LinkModels.swift
//  Cloudwrkz
//
//  Link and filter types for GET /api/links. Matches cloudwrkz API.
//

import Foundation

// MARK: - API response

struct LinksResponse: Decodable {
    let links: [Link]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}

struct Link: Identifiable, Decodable, Hashable {
    let id: String
    let title: String
    let url: String
    let description: String?
    let favicon: String?
    let linkType: String
    let tags: [String]
    let isFavorite: Bool
    let rating: Int?
    let createdAt: Date
    let updatedAt: Date
    let collections: [LinkCollectionRef]

    struct LinkCollectionRef: Decodable, Hashable {
        let collection: LinkCollectionInfo
    }

    struct LinkCollectionInfo: Decodable, Hashable {
        let id: String
        let name: String
        let color: String?
    }
}

// MARK: - Filter state (for future filter sheet)

struct LinkFilters: Equatable {
    var sort: LinkSortOption = .newestFirst
    var isFavorite: LinkFavoriteFilter = .all

    enum LinkSortOption: String, CaseIterable, Identifiable {
        case newestFirst = "createdAt-desc"
        case oldestFirst = "createdAt-asc"
        case updatedDesc = "updatedAt-desc"
        case updatedAsc = "updatedAt-asc"
        case titleAsc = "title-asc"
        case titleDesc = "title-desc"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .newestFirst: return "Newest first"
            case .oldestFirst: return "Oldest first"
            case .updatedDesc: return "Recently updated"
            case .updatedAsc: return "Least recently updated"
            case .titleAsc: return "Title (A–Z)"
            case .titleDesc: return "Title (Z–A)"
            }
        }
    }

    enum LinkFavoriteFilter: String, CaseIterable, Identifiable {
        case all = "all"
        case favorites = "true"
        case notFavorites = "false"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all: return "All links"
            case .favorites: return "Favorites only"
            case .notFavorites: return "Not favorites"
            }
        }
    }
}
