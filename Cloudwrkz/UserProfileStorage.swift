//
//  UserProfileStorage.swift
//  Cloudwrkz
//
//  Persists display name and optional profile image for the dashboard avatar.
//

import Foundation
import UIKit

struct UserProfileStorage {
    private static let firstNameKey = "cloudwrkz.userProfile.firstName"
    private static let lastNameKey = "cloudwrkz.userProfile.lastName"
    private static let profileImageKey = "cloudwrkz.userProfile.imageData"

    static var firstName: String? {
        get { UserDefaults.standard.string(forKey: firstNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: firstNameKey) }
    }

    static var lastName: String? {
        get { UserDefaults.standard.string(forKey: lastNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastNameKey) }
    }

    /// JPEG/PNG data for the profile image. Nil = use initials.
    static var profileImageData: Data? {
        get { UserDefaults.standard.data(forKey: profileImageKey) }
        set { UserDefaults.standard.set(newValue, forKey: profileImageKey) }
    }

    /// Clears profile when user logs out so the next account doesn’t show previous avatar.
    static func clear() {
        firstName = nil
        lastName = nil
        profileImageData = nil
    }
}
