//
//  ProfileView.swift
//  Cloudwrkz
//
//  Sheet showing user profile (name, avatar). Opened from profile icon context menu.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    var firstName: String?
    var lastName: String?
    var username: String?
    var profileImageData: Data?

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

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    ProfileAvatarView(
                        firstName: firstName,
                        lastName: lastName,
                        username: username,
                        profileImageData: profileImageData,
                        size: 100
                    )
                    .padding(.top, 20)

                    Text(displayName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(CloudwrkzColors.neutral100)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(CloudwrkzColors.primary400)
                }
            }
            .toolbarBackground(CloudwrkzColors.neutral950.opacity(0.95), for: .navigationBar)
            .tint(CloudwrkzColors.primary400)
        }
    }
}

#Preview {
    ProfileView(
        firstName: "Jane",
        lastName: "Doe",
        username: nil,
        profileImageData: nil
    )
}
