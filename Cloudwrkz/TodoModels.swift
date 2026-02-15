//
//  TodoModels.swift
//  Cloudwrkz
//
//  Todo and filter types for GET /api/todos. Matches cloudwrkz API.
//

import Foundation

// MARK: - API response

struct TodosResponse: Decodable {
    let todos: [Todo]
}

struct Todo: Identifiable, Decodable, Hashable {
    let id: String
    let todoNumber: String?
    let title: String
    let description: String?
    let descriptionPlain: String?
    let status: String
    let priority: String
    let estimatedHours: Double?
    let startDate: Date?
    let dueDate: Date?
    let completedDate: Date?
    let createdAt: Date
    let updatedAt: Date
    let parentTodoId: String?
    let ticketId: String?
    let assignedToId: String?
    let assignedTo: TodoUser?
    let ticket: TodoTicketRef?
    let _count: TodoCount?

    struct TodoUser: Decodable, Hashable {
        let id: String
        let name: String?
        let email: String
    }

    struct TodoTicketRef: Decodable, Hashable {
        let id: String
        let ticketNumber: String
        let title: String
    }

    struct TodoCount: Decodable, Hashable {
        let subtodos: Int
    }
}

// MARK: - Filter state (mirrors getAllTodos filters)

struct TodoFilters: Equatable {
    var status: TodoStatusFilter = .all
    var priority: TodoPriorityFilter = .all
    var sort: TodoSortOption = .newestFirst
    var archive: TodoArchiveFilter = .unarchived

    enum TodoStatusFilter: String, CaseIterable, Identifiable {
        case all = "ALL"
        case notStarted = "NOT_STARTED"
        case inProgress = "IN_PROGRESS"
        case blocked = "BLOCKED"
        case completed = "COMPLETED"
        case cancelled = "CANCELLED"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all: return "All statuses"
            case .notStarted: return "Not started"
            case .inProgress: return "In progress"
            case .blocked: return "Blocked"
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            }
        }
    }

    enum TodoPriorityFilter: String, CaseIterable, Identifiable {
        case all = "ALL"
        case low = "LOW"
        case medium = "MEDIUM"
        case high = "HIGH"
        case urgent = "URGENT"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all: return "All priorities"
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .urgent: return "Urgent"
            }
        }
    }

    enum TodoSortOption: String, CaseIterable, Identifiable {
        case newestFirst = "createdAt-desc"
        case oldestFirst = "createdAt-asc"
        case dueDateAsc = "dueDate-asc"
        case dueDateDesc = "dueDate-desc"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .newestFirst: return "Newest first"
            case .oldestFirst: return "Oldest first"
            case .dueDateAsc: return "Due date (earliest)"
            case .dueDateDesc: return "Due date (latest)"
            }
        }
    }

    enum TodoArchiveFilter: String, CaseIterable, Identifiable {
        case unarchived = "unarchived"
        case archived = "archived"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .unarchived: return "Active"
            case .archived: return "Archived"
            }
        }
    }
}
