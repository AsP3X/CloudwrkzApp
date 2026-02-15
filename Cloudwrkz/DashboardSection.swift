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

    var title: String { rawValue }

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
        case .home: return "Overview"
        case .tickets: return "Support tickets"
        case .todos: return "Tasks"
        case .links: return "Saved links"
        case .timeTracking: return "My time"
        case .archive: return "Archived items"
        }
    }
}
