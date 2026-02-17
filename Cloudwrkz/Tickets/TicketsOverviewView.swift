//
//  TicketsOverviewView.swift
//  Cloudwrkz
//
//  Enterprise ticket list with filter sheet. Matches cloudwrkz ticket list design.
//

import SwiftUI

struct TicketsOverviewView: View {
    @State private var tickets: [Ticket] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var filters = TicketFilters()
    @State private var showFilters = false

    private var hasActiveFilters: Bool {
        filters.status != .unresolved
            || filters.sort != .newestFirst
            || filters.createdFrom != nil
            || filters.createdTo != nil
            || filters.updatedFrom != nil
            || filters.updatedTo != nil
    }

    @Environment(\.appState) private var appState

    var body: some View {
        ZStack {
            background
            if isLoading && tickets.isEmpty {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if tickets.isEmpty {
                emptyView
            } else {
                ticketList
            }
        }
        .navigationTitle("Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(hasActiveFilters ? CloudwrkzColors.warning500 : CloudwrkzColors.primary400)
                }
            }
        }
        .tint(CloudwrkzColors.primary400)
        .sheet(isPresented: $showFilters) {
            TicketFiltersView(filters: $filters)
                .onDisappear { Task { await loadTickets() } }
        }
        .onAppear { Task { await loadTickets() } }
    }

    private var background: some View {
        LinearGradient(
            colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
CloudwrkzSpinner(tint: CloudwrkzColors.primary400)
            .scaleEffect(1.2)
            Text("Loading tickets…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CloudwrkzColors.neutral400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(CloudwrkzColors.warning500)
            Text("Couldn’t load tickets")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral100)
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CloudwrkzColors.neutral400)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") { Task { await loadTickets() } }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.primary400)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 48))
                .foregroundStyle(CloudwrkzColors.neutral500)
            Text("No tickets")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral100)
            Text("Change filters or create a ticket in the web app.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CloudwrkzColors.neutral500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var ticketList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(tickets) { ticket in
                    NavigationLink(value: ticket) {
                        TicketRowView(ticket: ticket)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .refreshable {
            await loadTickets()
        }
        .scrollContentBackground(.hidden)
    }

    /// Load tickets; supports pull-to-refresh (async) and onAppear. Keeps refresh indicator visible until load finishes.
    private func loadTickets() async {
        errorMessage = nil
        isLoading = true
        let result = await TicketService.fetchTickets(config: appState.config, filters: filters)
        await MainActor.run {
            switch result {
            case .success(let list):
                tickets = list
                errorMessage = nil
            case .failure(let err):
                tickets = []
                errorMessage = message(for: err)
            }
            isLoading = false
        }
    }

    private func message(for error: TicketServiceError) -> String {
        switch error {
        case .noServerURL: return "No server configured."
        case .noToken: return "Please sign in again."
        case .unauthorized: return "Session expired. Sign in again."
        case .serverError(let m): return m
        case .networkError: return "Could not reach server."
        }
    }
}

// MARK: - Ticket row (glass card, status/priority badges)

private struct TicketRowView: View {
    let ticket: Ticket

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ticket.ticketNumber)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(CloudwrkzColors.primary400)
                    HStack(spacing: 6) {
                        statusPill(ticket.status)
                        priorityPill(ticket.priority)
                        typePill(ticket.type)
                    }
                }
                Spacer(minLength: 8)
            }

            Text(ticket.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral100)
                .lineLimit(2)

            if let desc = ticket.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral400)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                if let assignee = ticket.assignedTo {
                    labelValue("Assigned", formatUser(assignee))
                } else if let group = ticket.assignedToGroup {
                    labelValue("Group", group.name)
                } else {
                    labelValue("Assigned", "Unassigned")
                }
                labelValue("Created", formatted(ticket.createdAt))
                if (ticket._count?.comments ?? 0) > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 12))
                        Text("\(ticket._count!.comments)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(CloudwrkzColors.neutral200)
                }
            }
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(CloudwrkzColors.neutral400)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassCard(cornerRadius: 16)
    }

    private func statusPill(_ status: String) -> some View {
        Text(status.replacingOccurrences(of: "_", with: " "))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.2), in: Capsule())
    }

    private func priorityPill(_ priority: String) -> some View {
        Text(priority)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(priorityColor(priority))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor(priority).opacity(0.2), in: Capsule())
    }

    private func typePill(_ type: String) -> some View {
        Text(type)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(CloudwrkzColors.neutral200)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(CloudwrkzColors.neutral700.opacity(0.8), in: Capsule())
    }

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "OPEN": return CloudwrkzColors.primary400
        case "IN_PROGRESS": return CloudwrkzColors.warning500
        case "PENDING": return CloudwrkzColors.warning400
        case "RESOLVED", "CLOSED": return CloudwrkzColors.success500
        case "CANCELLED": return CloudwrkzColors.neutral500
        default: return CloudwrkzColors.neutral400
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.uppercased() {
        case "URGENT": return CloudwrkzColors.error500
        case "HIGH": return CloudwrkzColors.warning500
        case "MEDIUM": return CloudwrkzColors.warning400
        default: return CloudwrkzColors.neutral400
        }
    }

    private func labelValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .foregroundStyle(CloudwrkzColors.neutral400)
            Text(value)
                .foregroundStyle(CloudwrkzColors.neutral100)
        }
    }

    private func formatUser(_ u: Ticket.TicketUser) -> String {
        if let n = u.name, !n.isEmpty { return n }
        return String(u.email.prefix(upTo: u.email.firstIndex(of: "@") ?? u.email.endIndex))
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        TicketsOverviewView()
    }
}
