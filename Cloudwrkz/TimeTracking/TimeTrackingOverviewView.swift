//
//  TimeTrackingOverviewView.swift
//  Cloudwrkz
//
//  Enterprise time tracking overview with liquid glass design.
//  Features: live-updating timers, stats cards, start/add actions, filter support.
//

import SwiftUI
import Combine

struct TimeTrackingOverviewView: View {
    @State private var entries: [TimeEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var filters = TimeTrackingFilters()
    @State private var showFilters = false

    private var hasActiveFilters: Bool {
        filters.status != .all
            || filters.sort != .newestFirst
            || filters.dateFrom != nil
            || filters.dateTo != nil
    }
    @State private var showStartTimer = false
    @State private var showAddEntry = false
    @State private var showActionMenu = false
    @State private var timerTick = Date()
    @State private var selectionMode = false
    @State private var selectedEntryIds: Set<String> = []
    @State private var pendingDeleteEntry: TimeEntry?
    @State private var editingEntry: TimeEntry?
    @State private var showBulkDeleteConfirm = false
    @State private var bulkActionInProgress = false

    @Environment(\.appState) private var appState
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            background

            if isLoading && entries.isEmpty {
                loadingView
            } else if let error = errorMessage, entries.isEmpty {
                errorView(error)
            } else if entries.isEmpty {
                emptyView
            } else {
                mainContent
            }
        }
        .navigationTitle("Time Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if selectionMode {
                    Button("Done") {
                        selectionMode = false
                        selectedEntryIds.removeAll()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.primary400)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectionMode {
                    Button(selectedEntryIds.count == entries.count ? "Deselect All" : "Select All") {
                        if selectedEntryIds.count == entries.count {
                            selectedEntryIds.removeAll()
                            selectionMode = false
                        } else {
                            selectedEntryIds = Set(entries.map(\.id))
                        }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CloudwrkzColors.primary400)
                } else {
                    HStack(spacing: 14) {
                        Button { showFilters = true } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(hasActiveFilters ? CloudwrkzColors.warning500 : CloudwrkzColors.primary400)
                        }
                        Menu {
                            Button {
                                showStartTimer = true
                            } label: {
                                Label("Start Timer", systemImage: "play.circle")
                            }
                            Button {
                                showAddEntry = true
                            } label: {
                                Label("Add Manual Entry", systemImage: "plus.circle")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(CloudwrkzColors.primary400)
                        }
                    }
                }
            }
        }
        .tint(CloudwrkzColors.primary400)
        .sheet(isPresented: $showFilters) {
            TimeTrackingFilterView(filters: $filters)
                .onDisappear { Task { await loadEntries() } }
        }
        .sheet(isPresented: $showStartTimer) {
            StartTimerSheet(onCreated: { Task { await loadEntries() } })
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddEntry) {
            AddTimeEntrySheet(onCreated: { Task { await loadEntries() } })
                .presentationDetents([.large])
        }
        .sheet(item: $editingEntry) { entry in
            EditTimeEntrySheet(
                entry: entry,
                onSaved: {
                    editingEntry = nil
                    Task { await loadEntries() }
                }
            )
            .presentationDetents([.large])
        }
        .onAppear { Task { await loadEntries() } }
        .onReceive(timer) { timerTick = $0 }
        .overlay {
            if showBulkDeleteConfirm {
                bulkDeleteConfirmationDialog
            } else if let entry = pendingDeleteEntry {
                deleteConfirmationDialog(for: entry)
            }
        }
        .overlay {
            if bulkActionInProgress {
                bulkActionLoadingOverlay
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                statsSection
                activeTimersSection
                allEntriesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, selectionMode ? 100 : 32)
        }
        .refreshable { await loadEntries() }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectionMode {
                bulkActionBar
            }
        }
    }

    // MARK: - Stats cards

    private var statsSection: some View {
        let activeCount = entries.filter { $0.status.isActive }.count
        let totalEntries = entries.count
        let totalSeconds = entries.reduce(0) { $0 + TimeTrackingUtils.calculateElapsedTime(entry: $1) }

        return HStack(spacing: 12) {
            StatCard(title: "Total", value: "\(totalEntries)", icon: "clock.fill", color: CloudwrkzColors.primary400)
            StatCard(title: "Active", value: "\(activeCount)", icon: "play.fill", color: CloudwrkzColors.success500)
            StatCard(title: "Time", value: TimeTrackingUtils.formatDurationHuman(totalSeconds), icon: "hourglass", color: CloudwrkzColors.warning400)
        }
        .id(timerTick)
    }

    // MARK: - Active timers section

    @ViewBuilder
    private var activeTimersSection: some View {
        let activeEntries = entries.filter { $0.status.isActive }
        if !activeEntries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(CloudwrkzColors.success500)
                        .frame(width: 8, height: 8)
                        .modifier(PulseAnimation())
                    Text("ACTIVE TIMERS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(CloudwrkzColors.success400)
                }

                ForEach(activeEntries) { entry in
                    let isSelected = selectedEntryIds.contains(entry.id)
                    Group {
                        if selectionMode {
                            ActiveTimerRow(entry: entry, tick: timerTick, isSelected: isSelected, selectionMode: true, onPause: {
                                Task { await performAction(.pause, on: entry) }
                            }, onResume: {
                                Task { await performAction(.resume, on: entry) }
                            }, onStop: {
                                Task { await performAction(.stop, on: entry) }
                            })
                            .onTapGesture { toggleSelection(for: entry) }
                        } else {
                            NavigationLink(value: entry) {
                                ActiveTimerRow(entry: entry, tick: timerTick, isSelected: false, selectionMode: false, onPause: {
                                    Task { await performAction(.pause, on: entry) }
                                }, onResume: {
                                    Task { await performAction(.resume, on: entry) }
                                }, onStop: {
                                    Task { await performAction(.stop, on: entry) }
                                })
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .contextMenu {
                        Button { toggleSelection(for: entry) } label: {
                            Label(isSelected ? "Deselect" : "Select", systemImage: isSelected ? "minus.circle" : "checkmark.circle")
                        }
                        if !selectionMode {
                            Button { editingEntry = entry } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            if entry.status.canPause {
                                Button { Task { await performAction(.pause, on: entry) } } label: {
                                    Label("Pause", systemImage: "pause.fill")
                                }
                            }
                            if entry.status.canResume {
                                Button { Task { await performAction(.resume, on: entry) } } label: {
                                    Label("Resume", systemImage: "play.fill")
                                }
                            }
                            if entry.status.canStop {
                                Button { Task { await performAction(.stop, on: entry) } } label: {
                                    Label("Stop", systemImage: "stop.fill")
                                }
                            }
                            Button(role: .destructive) { pendingDeleteEntry = entry } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - All entries section (excludes active timers shown above)

    private var allEntriesSection: some View {
        let stoppedEntries = entries.filter { !$0.status.isActive }
        return Group {
            if !stoppedEntries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ENTRIES")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(CloudwrkzColors.neutral500)

                    ForEach(stoppedEntries) { entry in
                        let isSelected = selectedEntryIds.contains(entry.id)
                        Group {
                            if selectionMode {
                                TimeEntryRow(entry: entry, tick: timerTick, isSelected: isSelected, selectionMode: true, onPause: {
                                    Task { await performAction(.pause, on: entry) }
                                }, onResume: {
                                    Task { await performAction(.resume, on: entry) }
                                }, onStop: {
                                    Task { await performAction(.stop, on: entry) }
                                })
                                .onTapGesture { toggleSelection(for: entry) }
                            } else {
                                NavigationLink(value: entry) {
                                    TimeEntryRow(entry: entry, tick: timerTick, isSelected: false, selectionMode: false, onPause: {
                                        Task { await performAction(.pause, on: entry) }
                                    }, onResume: {
                                        Task { await performAction(.resume, on: entry) }
                                    }, onStop: {
                                        Task { await performAction(.stop, on: entry) }
                                    })
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .contextMenu {
                            Button { toggleSelection(for: entry) } label: {
                                Label(isSelected ? "Deselect" : "Select", systemImage: isSelected ? "minus.circle" : "checkmark.circle")
                            }
                            if !selectionMode {
                                Button { editingEntry = entry } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) { pendingDeleteEntry = entry } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            CloudwrkzSpinner(tint: CloudwrkzColors.primary400)
                .scaleEffect(1.2)
            Text("Loading time entries…")
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
            Text("Couldn't load time entries")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral100)
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CloudwrkzColors.neutral400)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") { Task { await loadEntries() } }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.primary400)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.fill")
                .font(.system(size: 52))
                .foregroundStyle(CloudwrkzColors.neutral500)
            Text("No time entries")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral100)
            Text("Start a timer or add a manual entry to begin tracking your time.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CloudwrkzColors.neutral500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 14) {
                Button {
                    showStartTimer = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                        Text("Start Timer")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassButtonPrimary()
                }

                Button {
                    showAddEntry = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                        Text("Add Entry")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(CloudwrkzColors.primary400)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassButtonSecondary()
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private enum TimerAction { case pause, resume, stop }

    private func performAction(_ action: TimerAction, on entry: TimeEntry) async {
        let result: Result<Void, TimeTrackingServiceError>
        switch action {
        case .pause:
            result = await TimeTrackingService.pauseTimeEntry(config: appState.config, id: entry.id)
        case .resume:
            result = await TimeTrackingService.resumeTimeEntry(config: appState.config, id: entry.id)
        case .stop:
            result = await TimeTrackingService.stopTimeEntry(config: appState.config, id: entry.id)
        }

        switch result {
        case .success:
            await loadEntries()
        case .failure:
            break
        }
    }

    private func loadEntries() async {
        errorMessage = nil
        isLoading = true
        let result = await TimeTrackingService.fetchTimeEntries(config: appState.config, filters: filters)
        await MainActor.run {
            switch result {
            case .success(let list):
                entries = list
                errorMessage = nil
            case .failure(let err):
                entries = []
                errorMessage = message(for: err)
            }
            isLoading = false
        }
    }

    private func message(for error: TimeTrackingServiceError) -> String {
        switch error {
        case .noServerURL: return "No server configured."
        case .noToken: return "Please sign in again."
        case .unauthorized: return "Session expired. Sign in again."
        case .notFound: return "Time tracking not available."
        case .serverError(let m): return m
        case .networkError: return "Could not reach server."
        }
    }

    // MARK: - Selection

    private func toggleSelection(for entry: TimeEntry) {
        if selectedEntryIds.contains(entry.id) {
            selectedEntryIds.remove(entry.id)
            if selectedEntryIds.isEmpty { selectionMode = false }
        } else {
            selectedEntryIds.insert(entry.id)
            if !selectionMode { selectionMode = true }
        }
    }

    // MARK: - Single & bulk delete

    private func performSingleDelete(id: String) async {
        let result = await TimeTrackingService.deleteTimeEntry(config: appState.config, id: id)
        if case .success = result {
            await MainActor.run { entries.removeAll { $0.id == id } }
        }
    }

    private func performBulkDelete() async {
        await MainActor.run { bulkActionInProgress = true }
        let ids = Array(selectedEntryIds)
        var succeededIds: Set<String> = []
        await withTaskGroup(of: (String, Bool).self) { group in
            for id in ids {
                group.addTask {
                    let result = await TimeTrackingService.deleteTimeEntry(config: appState.config, id: id)
                    switch result {
                    case .success: return (id, true)
                    case .failure: return (id, false)
                    }
                }
            }
            for await (id, success) in group {
                if success { succeededIds.insert(id) }
            }
        }
        await MainActor.run {
            entries.removeAll { succeededIds.contains($0.id) }
            selectedEntryIds.subtract(succeededIds)
            if selectedEntryIds.isEmpty { selectionMode = false }
            bulkActionInProgress = false
        }
    }

    private func performBulkStop() async {
        await MainActor.run { bulkActionInProgress = true }
        let ids = Array(selectedEntryIds)
        for id in ids {
            _ = await TimeTrackingService.stopTimeEntry(config: appState.config, id: id)
        }
        await MainActor.run {
            selectedEntryIds.removeAll()
            selectionMode = false
            bulkActionInProgress = false
        }
        await loadEntries()
    }

    // MARK: - Bulk action bar

    private var bulkActionBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.primary400)
                Text("\(selectedEntryIds.count) selected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.neutral100)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(CloudwrkzColors.primary500.opacity(0.12))
                    .overlay(Capsule().stroke(CloudwrkzColors.primary400.opacity(0.25), lineWidth: 1))
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                bulkActionButton(icon: "stop.fill", label: "Stop", tint: CloudwrkzColors.warning500) {
                    Task { await performBulkStop() }
                }
                bulkActionButton(icon: "trash", label: "Delete", tint: CloudwrkzColors.error500) {
                    showBulkDeleteConfirm = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(CloudwrkzColors.neutral950.opacity(0.95))
        .overlay(alignment: .top) {
            Rectangle().frame(height: 1).foregroundStyle(CloudwrkzColors.divider)
        }
    }

    private func bulkActionButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(selectedEntryIds.isEmpty ? CloudwrkzColors.neutral600 : tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(bulkButtonGlass(tint: tint))
        }
        .disabled(selectedEntryIds.isEmpty)
        .buttonStyle(.plain)
    }

    private func bulkButtonGlass(tint: Color) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.clear)
                    .glassEffect(.regular.tint(tint.opacity(0.1)), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.3), lineWidth: 1))
            } else {
                Color.clear
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .background(tint.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.3), lineWidth: 1))
            }
        }
    }

    // MARK: - Delete confirmation dialog

    @ViewBuilder
    private func deleteConfirmationDialog(for entry: TimeEntry) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.error500)
                        Text("Delete time entry?")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                    }
                    Text("\u{201C}\(entry.name)\u{201D} will be permanently removed. This action can\u{2019}t be undone.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(CloudwrkzColors.neutral400)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    Button {
                        pendingDeleteEntry = nil
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(confirmDialogGlass)
                    Button {
                        let id = entry.id
                        pendingDeleteEntry = nil
                        Task { await performSingleDelete(id: id) }
                    } label: {
                        Text("Delete")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.neutral950)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(CloudwrkzColors.error500)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(CloudwrkzColors.glassStroke, lineWidth: 1))
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(confirmDialogPanel)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Bulk delete confirmation dialog

    private var bulkDeleteConfirmationDialog: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.error500)
                        Text("Delete \(selectedEntryIds.count) entries?")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                    }
                    Text("The selected time entries will be permanently removed. This action can\u{2019}t be undone.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(CloudwrkzColors.neutral400)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    Button {
                        showBulkDeleteConfirm = false
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(confirmDialogGlass)
                    Button {
                        showBulkDeleteConfirm = false
                        Task { await performBulkDelete() }
                    } label: {
                        Text("Delete")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.neutral950)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(CloudwrkzColors.error500)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(CloudwrkzColors.glassStroke, lineWidth: 1))
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(confirmDialogPanel)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Bulk action loading overlay

    private var bulkActionLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 18) {
                CloudwrkzSpinner(tint: CloudwrkzColors.primary400).scaleEffect(1.4)
                Text("Processing…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CloudwrkzColors.neutral400)
            }
            .padding(32)
            .background(confirmDialogPanel)
        }
    }

    // MARK: - Shared glass for confirmation dialogs

    private var confirmDialogGlass: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.clear)
                    .glassEffect(.regular.tint(CloudwrkzColors.glassFillSubtle), in: RoundedRectangle(cornerRadius: 14))
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var confirmDialogPanel: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.clear)
                    .glassEffect(.regular.tint(CloudwrkzColors.glassFillHighlight), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(CloudwrkzColors.glassStrokeSubtle, lineWidth: 1))
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(CloudwrkzColors.glassStrokeSubtle, lineWidth: 1))
            }
        }
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(CloudwrkzColors.neutral100)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(CloudwrkzColors.neutral400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(statGlass)
    }

    private var statGlass: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .glassEffect(.regular.tint(color.opacity(0.08)), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.25), lineWidth: 1)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.25), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Active timer row (large, prominent)

private struct ActiveTimerRow: View {
    let entry: TimeEntry
    let tick: Date
    var isSelected: Bool = false
    var selectionMode: Bool = false
    var onPause: () -> Void
    var onResume: () -> Void
    var onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if selectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? CloudwrkzColors.primary400 : CloudwrkzColors.neutral500)
                }
                statusIndicator
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CloudwrkzColors.neutral100)
                        .lineLimit(1)
                    if let desc = entry.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(CloudwrkzColors.neutral400)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                liveTimerDisplay
            }

            HStack(spacing: 10) {
                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(CloudwrkzColors.primary400)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(CloudwrkzColors.primary400.opacity(0.15), in: Capsule())
                        }
                    }
                }
                Spacer()
                actionButtons
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(activeRowGlass)
    }

    private var statusIndicator: some View {
        Image(systemName: entry.status == .running ? "play.circle.fill" : "pause.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(entry.status == .running ? CloudwrkzColors.success500 : CloudwrkzColors.warning500)
            .symbolEffect(.pulse, isActive: entry.status == .running)
    }

    private var liveTimerDisplay: some View {
        let elapsed = TimeTrackingUtils.calculateElapsedTime(entry: entry)
        return Text(TimeTrackingUtils.formatDuration(elapsed))
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .foregroundStyle(entry.status == .running ? CloudwrkzColors.success400 : CloudwrkzColors.warning400)
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.3), value: elapsed)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if entry.status.canPause {
                Button { onPause() } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CloudwrkzColors.warning400)
                        .frame(width: 36, height: 36)
                        .glassButtonSecondary(cornerRadius: 10)
                }
            }
            if entry.status.canResume {
                Button { onResume() } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CloudwrkzColors.success400)
                        .frame(width: 36, height: 36)
                        .glassButtonSecondary(cornerRadius: 10)
                }
            }
            if entry.status.canStop {
                Button { onStop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CloudwrkzColors.error500)
                        .frame(width: 36, height: 36)
                        .glassButtonSecondary(cornerRadius: 10)
                }
            }
        }
    }

    private var activeRowGlass: some View {
        let accent = entry.status == .running ? CloudwrkzColors.success500 : CloudwrkzColors.warning500
        let borderColor = isSelected ? CloudwrkzColors.primary400 : accent.opacity(0.3)
        let borderWidth: CGFloat = isSelected ? 2 : 1
        return Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(accent.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            }
        }
    }
}

// MARK: - Standard time entry row

private struct TimeEntryRow: View {
    let entry: TimeEntry
    let tick: Date
    var isSelected: Bool = false
    var selectionMode: Bool = false
    var onPause: () -> Void
    var onResume: () -> Void
    var onStop: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                if selectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? CloudwrkzColors.primary400 : CloudwrkzColors.neutral500)
                        .padding(.top, 2)
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(entry.name)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(CloudwrkzColors.primary400)
                        statusPill
                    }
                    if let desc = entry.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(CloudwrkzColors.neutral400)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                durationDisplay
            }

            HStack(spacing: 12) {
                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(CloudwrkzColors.primary400)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(CloudwrkzColors.primary400.opacity(0.12), in: Capsule())
                        }
                    }
                }
                Spacer()

                if entry.status.isActive {
                    compactActions
                }

                Text(Self.dateFormatter.string(from: entry.startedAt))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(rowGlass)
    }

    private var statusPill: some View {
        Text(entry.status.displayName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.2), in: Capsule())
    }

    private var durationDisplay: some View {
        let elapsed = TimeTrackingUtils.calculateElapsedTime(entry: entry)
        return Text(TimeTrackingUtils.formatDuration(elapsed))
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundStyle(entry.status.isActive ? CloudwrkzColors.success400 : CloudwrkzColors.neutral200)
            .contentTransition(.numericText())
    }

    private var compactActions: some View {
        HStack(spacing: 6) {
            if entry.status.canPause {
                Button { onPause() } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(CloudwrkzColors.warning400)
                        .frame(width: 28, height: 28)
                        .glassButtonSecondary(cornerRadius: 8)
                }
            }
            if entry.status.canResume {
                Button { onResume() } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(CloudwrkzColors.success400)
                        .frame(width: 28, height: 28)
                        .glassButtonSecondary(cornerRadius: 8)
                }
            }
            if entry.status.canStop {
                Button { onStop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(CloudwrkzColors.error500)
                        .frame(width: 28, height: 28)
                        .glassButtonSecondary(cornerRadius: 8)
                }
            }
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case .running: return CloudwrkzColors.success500
        case .paused: return CloudwrkzColors.warning500
        case .stopped: return CloudwrkzColors.neutral400
        case .completed: return CloudwrkzColors.primary400
        }
    }

    private var rowGlass: some View {
        let borderColor = isSelected ? CloudwrkzColors.primary400 : CloudwrkzColors.glassStroke
        let borderWidth: CGFloat = isSelected ? 2 : 1
        return Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .glassEffect(.regular.tint(CloudwrkzColors.glassFillHighlight), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            }
        }
    }
}

// MARK: - Pulse animation for active indicator

private struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.4 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

#Preview {
    NavigationStack {
        TimeTrackingOverviewView()
    }
}
