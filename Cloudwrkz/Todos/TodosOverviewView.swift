//
//  TodosOverviewView.swift
//  Cloudwrkz
//
//  Enterprise todo list with filter sheet. Matches cloudwrkz todo list design.
//

import SwiftUI

enum TodoOverviewViewStyle: String, CaseIterable {
    case card = "card"
    case list = "list"
}

private enum TodoListRowItem: Identifiable {
    case completedHeader
    case todo(Todo)

    var id: String {
        switch self {
        case .completedHeader: return "completed-header"
        case .todo(let t): return t.id
        }
    }
}

struct TodosOverviewView: View {
    @State private var todos: [Todo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var filters = TodoFilters()
    @State private var showFilters = false
    @State private var showAddTodo = false
    @AppStorage("todoOverviewViewStyle") private var viewStyleRaw: String = TodoOverviewViewStyle.card.rawValue

    private var viewStyle: TodoOverviewViewStyle {
        TodoOverviewViewStyle(rawValue: viewStyleRaw) ?? .card
    }

    private var hasActiveFilters: Bool {
        filters.status != .all
            || filters.priority != .all
            || filters.sort != .newestFirst
            || filters.archive != .unarchived
            || filters.includeSubtodos
    }

    @Environment(\.appState) private var appState

    var body: some View {
        ZStack {
            background
            if isLoading && todos.isEmpty {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if todos.isEmpty {
                emptyView
            } else {
                switch viewStyle {
                case .card: cardView
                case .list: listView
                }
            }
        }
        .navigationTitle("todo.nav_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .overlay(alignment: .bottomTrailing) {
            if !isLoading || !todos.isEmpty {
                addTodoButton
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        viewStyleRaw = TodoOverviewViewStyle.card.rawValue
                    } label: {
                        Label("todo.card_view", systemImage: "square.grid.2x2")
                    }
                    Button {
                        viewStyleRaw = TodoOverviewViewStyle.list.rawValue
                    } label: {
                        Label("todo.list_view", systemImage: "list.bullet")
                    }
                } label: {
                    Image(systemName: viewStyle == .card ? "square.grid.2x2" : "list.bullet")
                        .font(.system(size: 22))
                        .foregroundStyle(CloudwrkzColors.primary400)
                }
            }
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
            TodoFiltersView(filters: $filters)
                .onDisappear { Task { await loadTodos() } }
        }
        .sheet(isPresented: $showAddTodo) {
            AddTodoView(
                parentTodoId: nil,
                parentTodoTitle: nil,
                onSaved: { Task { await loadTodos() } }
            )
        }
        .onAppear { Task { await loadTodos() } }
    }

    /// Floating add-todo button, bottom right. Liquid glass style (matches Links).
    private var addTodoButton: some View {
        Button {
            showAddTodo = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral950)
                .frame(width: 56, height: 56)
                .background(CloudwrkzColors.primary400, in: Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 24)
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
            Text("todo.loading")
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
            Text("todo.load_error")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral100)
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CloudwrkzColors.neutral400)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("todo.retry") { Task { await loadTodos() } }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.primary400)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(CloudwrkzColors.neutral500)
            Text("todo.no_todos")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral100)
            Text("todo.empty_hint")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CloudwrkzColors.neutral500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(todos) { todo in
                    NavigationLink(value: todo) {
                        TodoRowView(todo: todo)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .refreshable {
            await loadTodos()
        }
        .scrollContentBackground(.hidden)
    }

    private var activeTodos: [Todo] {
        todos.filter { $0.status != "COMPLETED" }
    }

    private var completedTodos: [Todo] {
        todos.filter { $0.status == "COMPLETED" }
    }

    private var todoListRowItems: [TodoListRowItem] {
        let active: [TodoListRowItem] = activeTodos.map { .todo($0) }
        let header: [TodoListRowItem] = completedTodos.isEmpty ? [] : [.completedHeader]
        let completed: [TodoListRowItem] = completedTodos.map { .todo($0) }
        return active + header + completed
    }

    private var listView: some View {
        List {
            ForEach(todoListRowItems) { item in
                switch item {
                case .completedHeader:
                    Text("todo.completed_header")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(CloudwrkzColors.neutral500)
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                case .todo(let todo):
                    if todo.status == "COMPLETED" {
                        NavigationLink(value: todo) {
                            overviewCompletedRow(todo)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await deleteTodo(todo.id) }
                            } label: { Image(systemName: "trash") }
                            .tint(.red)
                        }
                    } else {
                        NavigationLink(value: todo) {
                            overviewActiveRow(todo)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await deleteTodo(todo.id) }
                            } label: { Image(systemName: "trash") }
                            .tint(.red)
                            Button {
                                Task { await completeTodo(todo.id) }
                            } label: { Image(systemName: "checkmark") }
                            .tint(CloudwrkzColors.success500)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await loadTodos()
        }
        .animation(.easeInOut(duration: 0.25), value: todoListRowItems.map(\.id))
    }

    private func overviewActiveRow(_ todo: Todo) -> some View {
        HStack(spacing: 14) {
            Button {
                Task { await completeTodo(todo.id) }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(CloudwrkzColors.neutral500)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.neutral100)
                    .lineLimit(2)
                Text(overviewTodoSubtitle(todo))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func overviewCompletedRow(_ todo: Todo) -> some View {
        HStack(spacing: 14) {
            Button {
                Task { await uncompleteTodo(todo.id) }
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(CloudwrkzColors.success500)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.neutral400)
                    .strikethrough(true, color: CloudwrkzColors.neutral500)
                    .lineLimit(2)
                Text(overviewTodoSubtitle(todo))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func overviewTodoSubtitle(_ todo: Todo) -> String {
        let status = todo.status.replacingOccurrences(of: "_", with: " ").lowercased()
        return "\(status) · \(todo.priority)"
    }

    private func completeTodo(_ id: String) async {
        let result = await TodoService.updateTodo(config: appState.config, id: id, status: "COMPLETED")
        guard case .success = result else { return }
        await loadTodos()
    }

    private func uncompleteTodo(_ id: String) async {
        let result = await TodoService.updateTodo(config: appState.config, id: id, status: "IN_PROGRESS")
        guard case .success = result else { return }
        await loadTodos()
    }

    private func deleteTodo(_ id: String) async {
        _ = await TodoService.deleteTodo(config: appState.config, id: id)
        await loadTodos()
    }

    /// Load todos; supports pull-to-refresh (async) and onAppear. Keeps refresh indicator visible until load finishes.
    private func loadTodos() async {
        errorMessage = nil
        isLoading = true
        let result = await TodoService.fetchTodos(config: appState.config, filters: filters)
        await MainActor.run {
            switch result {
            case .success(let list):
                todos = list
                errorMessage = nil
            case .failure(let err):
                todos = []
                errorMessage = message(for: err)
            }
            isLoading = false
        }
    }

    private func message(for error: TodoServiceError) -> String {
        switch error {
        case .noServerURL: return String(localized: "todo.no_server")
        case .noToken: return String(localized: "todo.please_sign_in")
        case .unauthorized: return String(localized: "todo.session_expired")
        case .serverError(let m): return m
        case .networkError: return String(localized: "auth.could_not_reach_server")
        }
    }
}

// MARK: - Todo row (glass card, status/priority badges)

private struct TodoRowView: View {
    let todo: Todo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    if let num = todo.todoNumber, !num.isEmpty {
                        Text(num)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(CloudwrkzColors.primary400)
                    }
                    HStack(spacing: 6) {
                        statusPill(todo.status)
                        priorityPill(todo.priority)
                    }
                }
                Spacer(minLength: 8)
            }

            Text(todo.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral100)
                .lineLimit(2)

            if let desc = todo.descriptionPlain ?? todo.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral400)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                if let assignee = todo.assignedTo {
                    labelValue(String(localized: "todo.assigned"), formatUser(assignee))
                } else {
                    labelValue(String(localized: "todo.assigned"), String(localized: "todo.unassigned"))
                }
                labelValue(String(localized: "todo.created"), formatted(todo.createdAt))
                if let ticket = todo.ticket {
                    HStack(spacing: 4) {
                        Image(systemName: "ticket")
                            .font(.system(size: 12))
                        Text(ticket.ticketNumber)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(CloudwrkzColors.neutral200)
                }
                if (todo._count?.subtodos ?? 0) > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet.indent")
                            .font(.system(size: 12))
                        Text("\(todo._count?.subtodos ?? 0)")
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

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "NOT_STARTED": return CloudwrkzColors.neutral400
        case "IN_PROGRESS": return CloudwrkzColors.primary400
        case "BLOCKED": return CloudwrkzColors.warning500
        case "COMPLETED": return CloudwrkzColors.success500
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

    private func formatUser(_ u: Todo.TodoUser) -> String {
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
        TodosOverviewView()
    }
}
