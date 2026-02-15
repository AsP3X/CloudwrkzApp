//
//  ProfileView.swift
//  Cloudwrkz
//
//  Sheet showing user profile: hero (avatar, name, email), member since, quick actions, sign out.
//  Liquid glass, modern enterprise. Opened from profile icon context menu.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    var firstName: String?
    var lastName: String?
    var username: String?
    var email: String?
    var profileImageData: Data?
    var onLogout: (() -> Void)?
    var onProfileUpdated: (() -> Void)?

    @State private var showEditSheet = false

    private var displayName: String {
        let first = firstName?.trimmingCharacters(in: .whitespaces) ?? ""
        let last = lastName?.trimmingCharacters(in: .whitespaces) ?? ""
        if !first.isEmpty || !last.isEmpty {
            return [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        }
        let trimmed = username?.trimmingCharacters(in: .whitespaces) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return "Profile"
    }

    private static let memberSinceFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private static func lastSignedInString(from date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

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
                    VStack(alignment: .leading, spacing: 24) {
                        heroSection
                        accountSection
                        sessionSection
                        versionSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(CloudwrkzColors.primary400)
                    .accessibilityLabel("Done")
                }
            }
            .toolbarBackground(CloudwrkzColors.neutral950.opacity(0.95), for: .navigationBar)
            .tint(CloudwrkzColors.primary400)
            .sheet(isPresented: $showEditSheet, onDismiss: {
                onProfileUpdated?()
            }) {
                ProfileEditView(onSave: {
                    showEditSheet = false
                    onProfileUpdated?()
                })
            }
        }
    }

    // MARK: - Hero (avatar + name + email + member since)

    private var heroSection: some View {
        VStack(spacing: 16) {
            ProfileAvatarView(
                firstName: firstName,
                lastName: lastName,
                username: username,
                profileImageData: profileImageData,
                size: 100
            )
            .accessibilityLabel("Profile photo")

            Text(displayName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(CloudwrkzColors.neutral100)

            if let email = email?.trimmingCharacters(in: .whitespaces), !email.isEmpty {
                Text(email)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral400)
            }

            if let username = username?.trimmingCharacters(in: .whitespaces), !username.isEmpty, username != displayName {
                Text(username)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }

            if let first = UserProfileStorage.firstLoginAt {
                Text("Member since \(Self.memberSinceFormatter.string(from: first))")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }

            if let last = UserProfileStorage.lastSignedInAt {
                Text("Last signed in \(Self.lastSignedInString(from: last))")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
    }

    // MARK: - Account section (quick actions)

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCOUNT")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(CloudwrkzColors.neutral500)
                .padding(.bottom, 4)

            ProfileGlassRowButton(
                icon: "pencil.circle.fill",
                title: "Edit profile",
                subtitle: "Name and photo",
                isDestructive: false
            ) {
                showEditSheet = true
            }
            .accessibilityLabel("Edit profile")
            .accessibilityHint("Opens edit profile screen")

            ProfileGlassRowButton(
                icon: "gearshape.fill",
                title: "Account settings",
                subtitle: "Preferences and security",
                isDestructive: false
            ) {
                // Placeholder: future AccountSettingsView or URL
            }

            ProfileGlassRowButton(
                icon: "bell.fill",
                title: "Notifications",
                subtitle: "Alerts and preferences",
                isDestructive: false
            ) {
                // Placeholder: future NotificationSettingsView
            }

            ProfileGlassRowButton(
                icon: "questionmark.circle.fill",
                title: "Help",
                subtitle: "Support and documentation",
                isDestructive: false
            ) {
                // Placeholder: open help URL
            }
        }
    }

    // MARK: - Session (sign out)

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SESSION")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(CloudwrkzColors.neutral500)
                .padding(.bottom, 4)

            ProfileGlassRowButton(
                icon: "rectangle.portrait.and.arrow.right",
                title: "Log out",
                subtitle: "Sign out of your account",
                isDestructive: true
            ) {
                dismiss()
                onLogout?()
            }
            .accessibilityLabel("Log out")
            .accessibilityHint("Signs out of your account")
        }
    }

    // MARK: - App version

    private var versionSection: some View {
        Text("Cloudwrkz \(appVersion)")
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(CloudwrkzColors.neutral500)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

// MARK: - Glass row (liquid glass, matches ProfileMenuPopoverView)

private struct ProfileGlassRowButton: View {
    var icon: String
    var title: String
    var subtitle: String
    var isDestructive: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isDestructive ? CloudwrkzColors.error500 : CloudwrkzColors.primary400)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDestructive ? CloudwrkzColors.error500 : CloudwrkzColors.neutral100)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(CloudwrkzColors.neutral500)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(profileRowGlass)
        }
        .buttonStyle(ProfileGlassRowButtonStyle())
    }

    private var profileRowGlass: some View {
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
}

private struct ProfileGlassRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ProfileView(
        firstName: "Jane",
        lastName: "Doe",
        username: nil,
        email: "jane@company.com",
        profileImageData: nil,
        onLogout: nil,
        onProfileUpdated: nil
    )
}
