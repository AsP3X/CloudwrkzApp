//
//  TimeTrackingOverviewView.swift
//  Cloudwrkz
//
//  Enterprise time tracking overview with liquid glass design.
//  Features: live-updating timers, stats cards, start/add actions, filter support.
//

import SwiftUI

struct TimeTrackingOverviewView: View {
    @State private var entries: [TimeEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var filters = TimeTrackingFilters()
    @State private var showFilters = false
    @State private var showStartTimer = false
    @State private var showAddEntry = false
    @State private var showActionMenu = false
    @State private var timerTick = Date()

    private let config = ServerConfig.load()
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
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Button { showFilters = true } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(CloudwrkzColors.primary400)
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
        .onAppear { Task { await loadEntries() } }
        .onReceive(timer) { timerTick = $0 }
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
            .padding(.bottom, 32)
        }
        .refreshable { await loadEntries() }
        .scrollContentBackground(.hidden)
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
                    NavigationLink(value: entry) {
                        ActiveTimerRow(entry: entry, tick: timerTick, onPause: {
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
        }
    }

    // MARK: - All entries section

    private var allEntriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ALL ENTRIES")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(CloudwrkzColors.neutral500)

            ForEach(entries) { entry in
                NavigationLink(value: entry) {
                    TimeEntryRow(entry: entry, tick: timerTick, onPause: {
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

    private enum TimerAction { case pause, resume, stop, complete }

    private func performAction(_ action: TimerAction, on entry: TimeEntry) async {
        let result: Result<Void, TimeTrackingServiceError>
        switch action {
        case .pause:
            result = await TimeTrackingService.pauseTimeEntry(config: config, id: entry.id)
        case .resume:
            result = await TimeTrackingService.resumeTimeEntry(config: config, id: entry.id)
        case .stop:
            result = await TimeTrackingService.stopTimeEntry(config: config, id: entry.id)
        case .complete:
            result = await TimeTrackingService.completeTimeEntry(config: config, id: entry.id)
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
        let result = await TimeTrackingService.fetchTimeEntries(config: config, filters: filters)
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
    var onPause: () -> Void
    var onResume: () -> Void
    var onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
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
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint((entry.status == .running ? CloudwrkzColors.success500 : CloudwrkzColors.warning500).opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke((entry.status == .running ? CloudwrkzColors.success500 : CloudwrkzColors.warning500).opacity(0.3), lineWidth: 1)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke((entry.status == .running ? CloudwrkzColors.success500 : CloudwrkzColors.warning500).opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Standard time entry row

private struct TimeEntryRow: View {
    let entry: TimeEntry
    let tick: Date
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
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.white.opacity(0.08)), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
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
