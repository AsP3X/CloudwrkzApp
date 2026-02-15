//
//  TicketModels.swift
//  Cloudwrkz
//
//  Ticket and filter types for GET /api/tickets. Matches cloudwrkz API.
//

import Foundation

// MARK: - API response

struct TicketsResponse: Decodable {
    let tickets: [Ticket]
}

struct Ticket: Identifiable, Decodable, Hashable {
    let id: String
    let ticketNumber: String
    let title: String
    let description: String?
    let type: String
    let status: String
    let priority: String
    let createdAt: Date
    let updatedAt: Date
    let createdBy: TicketUser?
    let assignedTo: TicketUser?
    let assignedToGroup: TicketGroup?
    let _count: TicketCount?

    struct TicketUser: Decodable, Hashable {
        let id: String
        let name: String?
        let email: String
    }

    struct TicketGroup: Decodable, Hashable {
        let id: String
        let name: String
        let description: String?
    }

    struct TicketCount: Decodable, Hashable {
        let comments: Int
    }
}

// MARK: - Filter state (mirrors TicketFilterConfig)

struct TicketFilters: Equatable {
    var status: TicketStatusFilter = .unresolved
    var sort: TicketSortOption = .newestFirst
    var createdFrom: Date?
    var createdTo: Date?
    var updatedFrom: Date?
    var updatedTo: Date?

    enum TicketStatusFilter: String, CaseIterable, Identifiable {
        case unresolved = "UNRESOLVED"
        case all = "ALL"
        case open = "OPEN"
        case inProgress = "IN_PROGRESS"
        case pending = "PENDING"
        case resolved = "RESOLVED"
        case closed = "CLOSED"
        case cancelled = "CANCELLED"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .unresolved: return "Unresolved"
            case .all: return "All statuses"
            case .open: return "Open"
            case .inProgress: return "In Progress"
            case .pending: return "Pending"
            case .resolved: return "Resolved"
            case .closed: return "Closed"
            case .cancelled: return "Cancelled"
            }
        }
    }

    enum TicketSortOption: String, CaseIterable, Identifiable {
        case newestFirst = "createdAt-desc"
        case oldestFirst = "createdAt-asc"
        case recentlyUpdated = "updatedAt-desc"
        case leastRecentlyUpdated = "updatedAt-asc"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .newestFirst: return "Newest first"
            case .oldestFirst: return "Oldest first"
            case .recentlyUpdated: return "Recently updated"
            case .leastRecentlyUpdated: return "Least recently updated"
            }
        }
    }
}
