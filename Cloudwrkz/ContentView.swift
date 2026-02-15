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

    /// Binding so the menu can open server config after dismissing. RootView owns the sheet.
    var showServerConfig: Binding<Bool> = .constant(false)
    /// Called when user taps Log out in the menu. RootView should clear token and navigate to splash.
    var onLogout: (() -> Void)? = nil

    /// Profile for avatar; refreshed on appear so edits elsewhere update the toolbar.
    @State private var profileFirstName: String? = UserProfileStorage.firstName
    @State private var profileLastName: String? = UserProfileStorage.lastName
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
                profileFirstName = UserProfileStorage.firstName
                profileLastName = UserProfileStorage.lastName
                profileImageData = UserProfileStorage.profileImageData
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showProfileMenu = true
                    } label: {
                        ProfileAvatarView(
                            firstName: profileFirstName,
                            lastName: profileLastName,
                            profileImageData: profileImageData,
                            size: 36
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 36, height: 36)
                    .fixedSize(horizontal: true, vertical: true)
                    .popover(isPresented: $showProfileMenu) {
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                showProfileMenu = false
                                showProfileSheet = true
                            } label: {
                                Label("View Profile", systemImage: "person.circle")
                            }
                            if onLogout != nil {
                                Button(role: .destructive) {
                                    showProfileMenu = false
                                    onLogout?()
                                } label: {
                                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            }
                        }
                        .padding()
                        .frame(minWidth: 200)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView(
                    firstName: profileFirstName,
                    lastName: profileLastName,
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
