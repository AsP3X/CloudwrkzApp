//
//  ProfileAvatarView.swift
//  Cloudwrkz
//
//  Profile icon: profile image in a circle, or initials (first letter of first + last name).
//

import SwiftUI

struct ProfileAvatarView: View {
    var firstName: String?
    var lastName: String?
    var profileImageData: Data?
    var size: CGFloat = 36

    private var initials: String {
        let first = (firstName?.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? "").uppercased()
        let last = (lastName?.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? "").uppercased()
        if first.isEmpty && last.isEmpty { return "?" }
        return first + last
    }

    var body: some View {
        Group {
            if let data = profileImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.neutral100)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(CloudwrkzColors.primary400.opacity(0.6), lineWidth: 1.5)
        )
    }
}

#Preview("Initials") {
    ZStack {
        Color.gray
        ProfileAvatarView(firstName: "Jane", lastName: "Doe", size: 44)
    }
}

#Preview("Fallback") {
    ZStack {
        Color.gray
        ProfileAvatarView(firstName: nil, lastName: nil, size: 44)
    }
}
