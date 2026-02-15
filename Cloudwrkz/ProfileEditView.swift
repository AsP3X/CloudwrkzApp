//
//  ProfileEditView.swift
//  Cloudwrkz
//
//  Edit profile: name fields and profile photo. Liquid glass, gradient background.
//

import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss

    var onSave: (() -> Void)?

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var profileImageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @FocusState private var focusedField: Field?

    private enum Field {
        case firstName, lastName
    }

    private let maxImageDimension: CGFloat = 400
    private let jpegQuality: CGFloat = 0.85

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
                        avatarSection
                        nameSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(CloudwrkzColors.primary400)
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.primary400)
                    .accessibilityLabel("Save")
                }
            }
            .toolbarBackground(CloudwrkzColors.neutral950.opacity(0.95), for: .navigationBar)
            .tint(CloudwrkzColors.primary400)
            .onAppear {
                loadFromStorage()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await loadSelectedPhoto(newItem)
                }
            }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ProfileAvatarView(
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName,
                    username: nil,
                    profileImageData: profileImageData,
                    size: 100
                )
                .overlay(
                    Circle()
                        .fill(.black.opacity(0.4))
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change profile photo")

            Text("Tap to change photo")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(CloudwrkzColors.neutral500)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NAME")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(CloudwrkzColors.neutral500)

            TextField("First name", text: $firstName)
                .textContentType(.givenName)
                .autocapitalization(.words)
                .focused($focusedField, equals: .firstName)
                .foregroundStyle(CloudwrkzColors.neutral100)
                .padding(14)
                .glassField(cornerRadius: 12)

            TextField("Last name", text: $lastName)
                .textContentType(.familyName)
                .autocapitalization(.words)
                .focused($focusedField, equals: .lastName)
                .foregroundStyle(CloudwrkzColors.neutral100)
                .padding(14)
                .glassField(cornerRadius: 12)
        }
    }

    private func loadFromStorage() {
        firstName = UserProfileStorage.firstName ?? ""
        lastName = UserProfileStorage.lastName ?? ""
        profileImageData = UserProfileStorage.profileImageData
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else {
            selectedPhotoItem = nil
            return
        }
        do {
            if let data = try await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                let resized = resizeAndCompress(uiImage)
                await MainActor.run {
                    profileImageData = resized
                }
            }
        } catch {
            // Keep previous image on failure
        }
    }

    private func resizeAndCompress(_ image: UIImage) -> Data? {
        let size = image.size
        let scale = min(maxImageDimension / size.width, maxImageDimension / size.height, 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        guard newSize.width > 0, newSize.height > 0 else { return nil }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: jpegQuality)
    }

    private func saveAndDismiss() {
        let first = firstName.trimmingCharacters(in: .whitespaces)
        let last = lastName.trimmingCharacters(in: .whitespaces)
        UserProfileStorage.firstName = first.isEmpty ? nil : first
        UserProfileStorage.lastName = last.isEmpty ? nil : last
        UserProfileStorage.profileImageData = profileImageData
        onSave?()
        dismiss()
    }
}

#Preview {
    ProfileEditView(onSave: nil)
}
