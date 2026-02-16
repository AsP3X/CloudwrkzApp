//
//  TodoDetailView.swift
//  Cloudwrkz
//
//  Enterprise todo detail with glass panels. Matches cloudwrkz todo detail layout.
//

import SwiftUI

struct TodoDetailView: View {
    @State private var todo: Todo
    @State private var showTodoInfoSidebar = false
    @State private var showAddTodo = false

    init(todo: Todo) {
        _todo = State(initialValue: todo)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    contentGrid
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle(todo.todoNumber ?? todo.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showAddTodo = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                    }
                    Button {
                        showTodoInfoSidebar = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .sheet(isPresented: $showTodoInfoSidebar) {
            TodoInfoSidebarView(todo: todo)
        }
        .sheet(isPresented: $showAddTodo) {
            AddTodoView(
                parentTodoId: todo.id,
                parentTodoTitle: todo.title,
                onSaved: { Task { await loadTodo() } }
            )
        }
        .tint(CloudwrkzColors.primary400)
        .task { await loadTodo() }
    }

    private func loadTodo() async {
        let result = await TodoService.fetchTodo(config: ServerConfig.load(), id: todo.id)
        await MainActor.run {
            if case .success(let updated) = result {
                todo = updated
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                if let num = todo.todoNumber, !num.isEmpty {
                    Text(num)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(CloudwrkzColors.primary400)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(CloudwrkzColors.primary400.opacity(0.15), in: Capsule())
                }
                HStack(spacing: 6) {
                    statusPill(todo.status)
                    priorityPill(todo.priority)
                }
            }
            Text(todo.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(CloudwrkzColors.neutral100)
                .fixedSize(horizontal: false, vertical: true)
            Text("Created \(Self.dateFormatter.string(from: todo.createdAt))")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(CloudwrkzColors.neutral400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(detailGlassPanel)
    }

    private var contentGrid: some View {
        mainColumn
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            descriptionCard
            ticketLinkCard
            subtodosSection
        }
    }

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(CloudwrkzColors.primary400)
                Text("Description")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(CloudwrkzColors.neutral100)
            }
            if let desc = todo.descriptionPlain ?? todo.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral200)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No description provided.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral500)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(detailGlassPanel)
    }

    private var ticketLinkCard: some View {
        Group {
            if let ticket = todo.ticket {
                HStack(spacing: 12) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(CloudwrkzColors.primary400.opacity(0.8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Linked ticket")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                        Text("\(ticket.ticketNumber) – \(ticket.title)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(CloudwrkzColors.neutral400)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(detailGlassPanel)
            }
        }
    }

    private var subtodosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Subtodos")
            VStack(spacing: 0) {
                if let subtodos = todo.subtodos, !subtodos.isEmpty {
                    ForEach(Array(subtodos.enumerated()), id: \.element.id) { index, subtodo in
                        NavigationLink(destination: TodoDetailLoaderView(todoId: subtodo.id)) {
                            subtodoSettingsRow(subtodo)
                        }
                        .buttonStyle(.plain)
                        if index < subtodos.count - 1 {
                            settingsDivider
                        }
                    }
                } else {
                    subtodoPlaceholderRow
                }
            }
            .padding(16)
            .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(CloudwrkzColors.neutral500)
            .padding(.bottom, 8)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 1)
    }

    /// One subtodo as a row matching Account Settings (Change password) style: icon, title, subtitle, chevron.
    private func subtodoSettingsRow(_ subtodo: Todo.TodoSubtask) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 20))
                .foregroundStyle(CloudwrkzColors.primary400)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(subtodo.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.neutral100)
                    .lineLimit(2)
                Text(subtodoStatusSubtitle(subtodo))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral500)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func subtodoStatusSubtitle(_ subtodo: Todo.TodoSubtask) -> String {
        let status = subtodo.status.replacingOccurrences(of: "_", with: " ").lowercased()
        let priority = subtodo.priority
        return "\(status) · \(priority)"
    }

    private var subtodoPlaceholderRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 20))
                .foregroundStyle(CloudwrkzColors.neutral500)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("No subtodos")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.neutral100)
                Text("Tap + to add one")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailGlassPanel: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.white.opacity(0.06)), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            }
        }
    }

    private func statusPill(_ status: String) -> some View {
        Text(status.replacingOccurrences(of: "_", with: " "))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor(status).opacity(0.2), in: Capsule())
    }

    private func priorityPill(_ priority: String) -> some View {
        Text(priority)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(priorityColor(priority))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
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
}

// MARK: - Todo info sidebar (sheet)

private struct TodoInfoSidebarView: View {
    let todo: Todo
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                ScrollView {
                    todoInfoContent
                        .padding(20)
                        .padding(.bottom, 32)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Todo information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(CloudwrkzColors.neutral950.opacity(0.95), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.primary400)
                }
            }
            .tint(CloudwrkzColors.primary400)
        }
    }

    private var todoInfoContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(CloudwrkzColors.primary400)
                Text("Todo information")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(CloudwrkzColors.neutral100)
            }
            VStack(alignment: .leading, spacing: 14) {
                if let num = todo.todoNumber {
                    infoRow(label: "Todo ID", value: num, mono: true)
                }
                infoRow(label: "Status", value: todo.status.replacingOccurrences(of: "_", with: " "))
                infoRow(label: "Priority", value: todo.priority)
                sidebarDivider
                infoRow(label: "Assigned to", value: formatAssignedTo())
                sidebarDivider
                infoRow(label: "Created", value: Self.dateFormatter.string(from: todo.createdAt))
                if todo.updatedAt != todo.createdAt {
                    infoRow(label: "Last updated", value: Self.dateFormatter.string(from: todo.updatedAt))
                }
                if let due = todo.dueDate {
                    sidebarDivider
                    infoRow(label: "Due date", value: Self.dateFormatter.string(from: due))
                }
                if let completed = todo.completedDate {
                    infoRow(label: "Completed", value: Self.dateFormatter.string(from: completed))
                }
                if (todo._count?.subtodos ?? 0) > 0 {
                    sidebarDivider
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.indent")
                            .font(.system(size: 12))
                            .foregroundStyle(CloudwrkzColors.neutral400)
                        Text("\(todo._count!.subtodos) subtodo\(todo._count!.subtodos == 1 ? "" : "s")")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CloudwrkzColors.neutral200)
                    }
                }
                if todo.ticket != nil {
                    sidebarDivider
                    infoRow(label: "Linked ticket", value: todo.ticket!.ticketNumber)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sidebarGlassPanel)
    }

    private func infoRow(label: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(CloudwrkzColors.neutral500)
            Text(value)
                .font(.system(size: 14, weight: mono ? .semibold : .regular, design: mono ? .monospaced : .default))
                .foregroundStyle(CloudwrkzColors.neutral100)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(CloudwrkzColors.neutral700.opacity(0.6))
            .frame(height: 1)
    }

    private var sidebarGlassPanel: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.white.opacity(0.06)), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            }
        }
    }

    private func formatAssignedTo() -> String {
        guard let assignee = todo.assignedTo else { return "Unassigned" }
        if let n = assignee.name, !n.isEmpty { return n }
        return String(assignee.email.prefix(upTo: assignee.email.firstIndex(of: "@") ?? assignee.email.endIndex))
    }
}

// MARK: - Todo detail by ID (loads then shows detail; used when navigating from subtodo row)

struct TodoDetailLoaderView: View {
    let todoId: String
    @State private var todo: Todo?
    @State private var errorMessage: String?

    private let config = ServerConfig.load()

    var body: some View {
        Group {
            if let todo = todo {
                TodoDetailView(todo: todo)
            } else if let error = errorMessage {
                errorView(error)
            } else {
                loadingView
            }
        }
        .task { await loadTodo() }
    }

    private func loadTodo() async {
        let result = await TodoService.fetchTodo(config: config, id: todoId)
        await MainActor.run {
            switch result {
            case .success(let loaded):
                todo = loaded
                errorMessage = nil
            case .failure(let err):
                todo = nil
                errorMessage = message(for: err)
            }
        }
    }

    private var loadingView: some View {
        ZStack {
            LinearGradient(
                colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            VStack(spacing: 16) {
                CloudwrkzSpinner(tint: CloudwrkzColors.primary400)
                    .scaleEffect(1.2)
                Text("Loading…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CloudwrkzColors.neutral400)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func errorView(_ message: String) -> some View {
        ZStack {
            LinearGradient(
                colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(CloudwrkzColors.warning500)
                Text("Couldn't load todo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.neutral100)
                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral400)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func message(for error: TodoServiceError) -> String {
        switch error {
        case .noServerURL: return "No server configured."
        case .noToken: return "Please sign in again."
        case .unauthorized: return "Session expired. Sign in again."
        case .serverError(let m): return m
        case .networkError: return "Could not reach server."
        }
    }
}

#Preview {
    let json = """
    {"id":"preview-1","todoNumber":"#TDO-000042","title":"Implement todo view for the iOS app","description":"Add overview and detail matching ticket view.","descriptionPlain":"Add overview and detail matching ticket view.","status":"IN_PROGRESS","priority":"HIGH","estimatedHours":null,"startDate":null,"dueDate":null,"completedDate":null,"createdAt":"2025-01-15T12:00:00Z","updatedAt":"2025-01-15T12:00:00Z","parentTodoId":null,"ticketId":null,"assignedToId":"u1","assignedTo":{"id":"u1","name":"Jane Doe","email":"jane@example.com"},"ticket":{"id":"t1","ticketNumber":"TKT-001","title":"Sample ticket"},"subtodos":[{"id":"st1","title":"Design detail layout","status":"COMPLETED","priority":"MEDIUM"},{"id":"st2","title":"Implement glass panels","status":"IN_PROGRESS","priority":"HIGH"}],"_count":{"subtodos":2}}
    """
    let data = Data(json.utf8)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    guard let todo = try? decoder.decode(Todo.self, from: data) else {
        return Text("Preview unavailable")
    }
    return NavigationStack {
        TodoDetailView(todo: todo)
    }
}
