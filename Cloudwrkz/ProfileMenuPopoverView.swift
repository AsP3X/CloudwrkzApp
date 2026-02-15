//
//  ProfileMenuPopoverView.swift
//  Cloudwrkz
//
//  Profile context menu. Liquid glass only — fancy, modern, enterprise.
//

import SwiftUI

struct ProfileMenuPopoverView: View {
    var firstName: String?
    var lastName: String?
    var username: String?
    var email: String?
    var profileImageData: Data?
    var onViewProfile: () -> Void
    var onQrLogin: (() -> Void)?
    var onLogout: (() -> Void)?

    /// Display order: first+last name (profile) → username (API user.name) → email prefix → "Profile".
    /// Matches cloudwrkz formatUserName: show name, or email.split("@")[0], never full email as display name.
    /// Falls back to UserProfileStorage when passed-in values are nil (e.g. menu opened before state refreshed).
    private var displayName: String {
        let first = firstName?.trimmingCharacters(in: .whitespaces) ?? ""
        let last = lastName?.trimmingCharacters(in: .whitespaces) ?? ""
        if !first.isEmpty || !last.isEmpty {
            return [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        }
        let trimmedUsername = username?.trimmingCharacters(in: .whitespaces)
            ?? UserProfileStorage.username?.trimmingCharacters(in: .whitespaces)
            ?? ""
        if !trimmedUsername.isEmpty { return trimmedUsername }
        let emailForPrefix = email?.trimmingCharacters(in: .whitespaces)
            ?? UserProfileStorage.email?.trimmingCharacters(in: .whitespaces)
            ?? ""
        let emailPrefix = emailPrefix(from: emailForPrefix)
        if !emailPrefix.isEmpty { return emailPrefix }
        return "Profile"
    }

    /// Part before @ (matches cloudwrkz formatUserName fallback).
    private func emailPrefix(from email: String) -> String {
        guard let at = email.firstIndex(of: "@") else { return email }
        return String(email[..<at]).trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                headerSection
                divider
                sectionLabel("ACCOUNT")
                viewProfileRow
                if onQrLogin != nil {
                    qrLoginRow
                }
                if onLogout != nil {
                    sectionLabel("SESSION")
                    logOutRow
                }
            }
            .padding(20)
            .frame(minWidth: 280)
            .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
            .padding(16)
        }
        .presentationCompactAdaptation(.popover)
    }

    private var headerSection: some View {
        HStack(spacing: 14) {
            ProfileAvatarView(
                firstName: firstName,
                lastName: lastName,
                username: username ?? UserProfileStorage.username,
                profileImageData: profileImageData,
                size: 44
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.neutral100)
                Text("Signed in")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 16)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(CloudwrkzColors.neutral500)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    private var viewProfileRow: some View {
        MenuRowButton(
            icon: "person.circle.fill",
            title: "View Profile",
            subtitle: "Name, avatar, settings"
        ) {
            onViewProfile()
        }
    }

    private var qrLoginRow: some View {
        MenuRowButton(
            icon: "qrcode",
            title: "Login with QR code",
            subtitle: "Sign in on the website by scanning"
        ) {
            onQrLogin?()
        }
    }

    private var logOutRow: some View {
        MenuRowButton(
            icon: "rectangle.portrait.and.arrow.right",
            title: "Log out",
            subtitle: "Sign out of your account",
            isDestructive: true
        ) {
            onLogout?()
        }
    }
}

// MARK: - Glass menu row (liquid glass)

private struct MenuRowButton: View {
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
            .background(menuRowGlass)
        }
        .buttonStyle(ProfileMenuRowButtonStyle())
    }

    private var menuRowGlass: some View {
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

private struct ProfileMenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ProfileMenuPopoverView(
        firstName: "Jane",
        lastName: "Doe",
        username: nil,
        email: "jane@company.com",
        profileImageData: nil,
        onViewProfile: {},
        onQrLogin: {},
        onLogout: {}
    )
}
