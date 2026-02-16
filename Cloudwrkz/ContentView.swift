//
//  ContentView.swift
//  Cloudwrkz
//
//  Single-column dashboard: menu (same row design) as main content, tap pushes to section.
//

import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()

    /// True when the main (dashboard) screen is shown. When this flips to true after login, we refresh profile so the avatar shows the new user.
    var isMainVisible: Bool = true
    /// Binding so the menu can open server config after dismissing. RootView owns the sheet.
    var showServerConfig: Binding<Bool> = .constant(false)
    /// Called when user taps Log out in the menu. RootView should clear token and navigate to splash.
    var onLogout: (() -> Void)? = nil

    /// Profile for avatar and menu; refreshed on appear so edits elsewhere update the toolbar.
    @State private var profileFirstName: String? = UserProfileStorage.firstName
    @State private var profileLastName: String? = UserProfileStorage.lastName
    @State private var profileEmail: String? = UserProfileStorage.email
    @State private var profileUsername: String? = UserProfileStorage.username
    @State private var profileImageData: Data? = UserProfileStorage.profileImageData

    /// Present profile sheet when "View Profile" is chosen from context menu.
    @State private var showProfileSheet = false
    /// Present profile menu (popover) when profile button is tapped.
    @State private var showProfileMenu = false
    /// Present QR login scanner when user chooses "Login with QR code" from profile menu.
    @State private var showQrScanner = false
    /// Present search overlay when user swipes down and holds on dashboard (or taps toolbar search).
    @State private var showSearch = false
    /// When true, show search after the current sheet/fullScreenCover has finished dismissing (avoids "already presenting").
    @State private var pendingSearchAfterDismiss = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(
                    colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        welcomeSection
                        menuSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
                .overlay {
                    PullDownToSearchView(onTrigger: { requestSearch() })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(true)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: DashboardSection.self) { section in
                if section == .tickets {
                    TicketsOverviewView()
                } else if section == .todos {
                    TodosOverviewView()
                } else if section == .links {
                    LinksOverviewView()
                } else if section == .timeTracking {
                    TimeTrackingOverviewView()
                } else {
                    DashboardSectionPlaceholderView(section: section)
                }
            }
            .navigationDestination(for: Ticket.self) { ticket in
                TicketDetailView(ticket: ticket)
            }
            .navigationDestination(for: Todo.self) { todo in
                TodoDetailView(todo: todo)
            }
            .navigationDestination(for: Link.self) { link in
                LinkDetailView(link: link, serverBaseURL: ServerConfig.load().baseURL)
            }
            .navigationDestination(for: TimeEntry.self) { entry in
                TimeEntryDetailView(entry: entry)
            }
            .onAppear {
                refreshProfileFromStorage()
                if AuthTokenStorage.getToken() != nil {
                    Task { @MainActor in
                        let config = ServerConfig.load()
                        switch await AuthService.fetchCurrentUser(config: config) {
                        case .success((let name, let email)):
                            if let n = name?.trimmingCharacters(in: .whitespaces), !n.isEmpty {
                                UserProfileStorage.username = n
                            }
                            if let e = email?.trimmingCharacters(in: .whitespaces), !e.isEmpty {
                                UserProfileStorage.email = e
                            }
                            refreshProfileFromStorage()
                        case .failure:
                            break
                        }
                    }
                }
            }
            .onChange(of: isMainVisible) { _, visible in
                if visible {
                    refreshProfileFromStorage()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        requestSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        refreshProfileFromStorage()
                        showProfileMenu = true
                    } label: {
                        ProfileAvatarView(
                            firstName: profileFirstName ?? UserProfileStorage.firstName,
                            lastName: profileLastName ?? UserProfileStorage.lastName,
                            username: profileUsername ?? UserProfileStorage.username,
                            profileImageData: profileImageData ?? UserProfileStorage.profileImageData,
                            size: 36
                        )
                        .id(profileUsername ?? UserProfileStorage.username ?? profileFirstName ?? profileLastName ?? "avatar")
                    }
                    .buttonStyle(.plain)
                    .frame(width: 36, height: 36)
                    .fixedSize(horizontal: true, vertical: true)
                    .popover(isPresented: $showProfileMenu) {
                        ProfileMenuPopoverView(
                            firstName: profileFirstName,
                            lastName: profileLastName,
                            username: profileUsername,
                            email: profileEmail,
                            profileImageData: profileImageData,
                            onViewProfile: {
                                showProfileMenu = false
                                DispatchQueue.main.async {
                                    showProfileSheet = true
                                }
                            },
                            onQrLogin: {
                                showProfileMenu = false
                                DispatchQueue.main.async {
                                    showQrScanner = true
                                }
                            },
                            onLogout: onLogout != nil ? {
                                showProfileMenu = false
                                onLogout?()
                            } : nil
                        )
                    }
                }
            }
            .sheet(isPresented: $showProfileSheet, onDismiss: {
                if pendingSearchAfterDismiss {
                    pendingSearchAfterDismiss = false
                    showSearch = true
                }
            }) {
                ProfileView(
                    firstName: profileFirstName,
                    lastName: profileLastName,
                    username: profileUsername,
                    email: profileEmail,
                    profileImageData: profileImageData,
                    onLogout: onLogout != nil ? {
                        showProfileSheet = false
                        onLogout?()
                    } : nil,
                    onProfileUpdated: { refreshProfileFromStorage() }
                )
            }
            .fullScreenCover(isPresented: $showSearch) {
                DashboardSearchView(onDismiss: { showSearch = false })
            }
            .fullScreenCover(isPresented: $showQrScanner) {
                QrLoginScannerView(onDismiss: { showQrScanner = false })
            }
            .tint(CloudwrkzColors.primary400)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var welcomeSection: some View {
        Text("Welcome back. Choose a section from the menu or use the shortcuts below.")
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(CloudwrkzColors.neutral400)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK ACCESS")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(CloudwrkzColors.neutral500)

            VStack(spacing: 10) {
                ForEach(DashboardSection.allCases.filter { $0 != .home }) { section in
                    NavigationLink(value: section) {
                        HStack(spacing: 16) {
                            Image(systemName: section.iconName)
                                .font(.system(size: 20))
                                .foregroundStyle(CloudwrkzColors.primary400)
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(CloudwrkzColors.neutral100)
                                Text(section.subtitle)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(CloudwrkzColors.neutral500)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(CloudwrkzColors.neutral500)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(menuCardGlass)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var menuCardGlass: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.white.opacity(0.04)), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
    }

    private func refreshProfileFromStorage() {
        profileFirstName = UserProfileStorage.firstName
        profileLastName = UserProfileStorage.lastName
        profileEmail = UserProfileStorage.email
        profileUsername = UserProfileStorage.username
        profileImageData = UserProfileStorage.profileImageData
    }

    /// Presents search, or defers it until profile sheet has dismissed to avoid "already presenting".
    private func requestSearch() {
        if showProfileSheet {
            pendingSearchAfterDismiss = true
            showProfileSheet = false
        } else {
            showSearch = true
        }
    }

}

#Preview {
    ContentView()
}
