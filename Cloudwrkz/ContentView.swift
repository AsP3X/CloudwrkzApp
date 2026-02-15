//
//  ContentView.swift
//  Cloudwrkz
//
//  Liquid glass only. Enterprise main content.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

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

    var body: some View {
        NavigationSplitView {
            ZStack {
                LinearGradient(
                    colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                List {
                    ForEach(items) { item in
                        NavigationLink {
                            detailContent(for: item)
                        } label: {
                            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(CloudwrkzColors.neutral100)
                        }
                        .listRowBackground(listRowGlass)
                        .listRowSeparatorTint(.white.opacity(0.12))
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refreshProfileFromStorage()
                // Always refresh profile from server when we have a token so we show the account name (e.g. "Niklas Vorberg"), not email prefix
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
                                showProfileSheet = true
                            },
                            onLogout: onLogout != nil ? {
                                showProfileMenu = false
                                onLogout?()
                            } : nil
                        )
                    }
                }
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView(
                    firstName: profileFirstName,
                    lastName: profileLastName,
                    username: profileUsername,
                    profileImageData: profileImageData
                )
            }
            .tint(CloudwrkzColors.primary400)
            .toolbarBackground(CloudwrkzColors.neutral950.opacity(0.95), for: .navigationBar)
        } detail: {
            ZStack {
                LinearGradient(
                    colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .toolbarBackground(CloudwrkzColors.neutral950.opacity(0.95), for: .navigationBar)
            .overlay {
                Text("Select an item")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
        }
    }

    @ViewBuilder
    private func detailContent(for item: Item) -> some View {
        ZStack {
            LinearGradient(
                colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(CloudwrkzColors.neutral100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)
                .glassPanel(cornerRadius: 20)
                .padding(20)
        }
    }

    private func refreshProfileFromStorage() {
        profileFirstName = UserProfileStorage.firstName
        profileLastName = UserProfileStorage.lastName
        profileEmail = UserProfileStorage.email
        profileUsername = UserProfileStorage.username
        profileImageData = UserProfileStorage.profileImageData
    }

    private var listRowGlass: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.white.opacity(0.04)), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            } else {
                Color.clear
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
