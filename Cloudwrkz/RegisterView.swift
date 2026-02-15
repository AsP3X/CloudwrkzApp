//
//  RegisterView.swift
//  Cloudwrkz
//
//  Liquid glass only. Matches root auth (Splash/Login) layout and styling.
//

import SwiftUI

struct RegisterView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    var serverConfig: ServerConfig = ServerConfig.load()
    var onSuccess: () -> Void = {}
    var onBack: () -> Void = {}

    enum Field { case name, email, password, confirmPassword }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CloudwrkzColors.primary950, CloudwrkzColors.neutral950],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer(minLength: 0)

                VStack(spacing: 24) {
                    Text("Create account")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    formFields
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)

                VStack(spacing: 14) {
                    Button(action: submit) {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create account")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .glassButtonPrimary()
                    .disabled(isLoading || !isFormValid)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .padding(.top, 24)
            }
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.isEmpty
            && !password.isEmpty
            && !confirmPassword.isEmpty
    }

    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("NAME")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(CloudwrkzColors.neutral400)
                TextField("Your name", text: $name)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .focused($focusedField, equals: .name)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .glassField(cornerRadius: 10)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("EMAIL")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(CloudwrkzColors.neutral400)
                TextField("you@company.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .glassField(cornerRadius: 10)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("PASSWORD")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(CloudwrkzColors.neutral400)
                SecureField("Choose a password", text: $password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .glassField(cornerRadius: 10)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("CONFIRM PASSWORD")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(CloudwrkzColors.neutral400)
                SecureField("Confirm your password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .glassField(cornerRadius: 10)
            }

            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(CloudwrkzColors.error500)
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CloudwrkzColors.error500)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(CloudwrkzColors.error50.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(CloudwrkzColors.error500.opacity(0.35), lineWidth: 1)
                )
            }
        }
    }

    private func submit() {
        errorMessage = nil
        focusedField = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errorMessage = "Please enter your name."
            return
        }
        if trimmedName.count < 2 {
            errorMessage = "Name must be at least 2 characters."
            return
        }
        if email.isEmpty {
            errorMessage = "Please enter your email."
            return
        }
        if password.isEmpty {
            errorMessage = "Please choose a password."
            return
        }
        if password != confirmPassword {
            errorMessage = "Passwords do not match."
            return
        }
        if password.count < 8 {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        if serverConfig.baseURL == nil {
            errorMessage = "Configure server in settings."
            return
        }

        isLoading = true
        Task { @MainActor in
            defer { isLoading = false }
            let result = await AuthService.register(
                name: trimmedName,
                email: email,
                password: password,
                confirmPassword: confirmPassword,
                config: serverConfig
            )
            switch result {
            case .success:
                let parts = trimmedName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                UserProfileStorage.firstName = parts.first.map(String.init)
                UserProfileStorage.lastName = (parts.count > 1) ? String(parts[1]) : nil
                onSuccess()
            case .failure(let failure):
                errorMessage = message(for: failure)
            }
        }
    }

    private func message(for failure: AuthRegisterFailure) -> String {
        switch failure {
        case .noServerURL:
            return "Configure server in settings."
        case .serverError(let message):
            return message
        case .networkError:
            return "Could not reach server."
        }
    }
}

#Preview {
    RegisterView()
}
