//
//  DashboardSection.swift
//  Cloudwrkz
//
//  Dashboard sidebar sections. Matches cloudwrkz web app (Work, Personal).
//

import SwiftUI

/// Sections shown in the dashboard sidebar. Order and icons align with the web app.
enum DashboardSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case tickets = "Tickets"
    case todos = "ToDo"
    case links = "Links"
    case timeTracking = "Time tracking"
    case archive = "Archive"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return String(localized: "dashboard.section.home")
        case .tickets: return String(localized: "dashboard.section.tickets")
        case .todos: return String(localized: "dashboard.section.todos")
        case .links: return String(localized: "dashboard.section.links")
        case .timeTracking: return String(localized: "dashboard.section.time_tracking")
        case .archive: return String(localized: "dashboard.section.archive")
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .tickets: return "ticket.fill"
        case .todos: return "checklist"
        case .links: return "link"
        case .timeTracking: return "clock.fill"
        case .archive: return "archivebox.fill"
        }
    }

    /// Short subtitle for sidebar or home quick-access.
    var subtitle: String {
        switch self {
        case .home: return String(localized: "dashboard.section.overview")
        case .tickets: return String(localized: "dashboard.section.support_tickets")
        case .todos: return String(localized: "dashboard.section.tasks")
        case .links: return String(localized: "dashboard.section.saved_links")
        case .timeTracking: return String(localized: "dashboard.section.my_time")
        case .archive: return String(localized: "dashboard.section.archived_items")
        }
    }
}
