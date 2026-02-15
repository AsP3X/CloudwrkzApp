//
//  LoginView.swift
//  Cloudwrkz
//
//  Liquid glass only. Matches root auth (Splash/Register) layout and styling.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    var onSuccess: () -> Void = {}
    var onBack: () -> Void = {}

    enum Field { case email, password }

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
                    Text("Sign in")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    formFields
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)

                // Buttons at bottom, no panel – same as Splash
                VStack(spacing: 14) {
                    Button(action: submit) {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign in")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .glassButtonPrimary()
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .padding(.top, 24)
            }
        }
    }

    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: 18) {
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
                SecureField("Enter your password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
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
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            if email.isEmpty || password.isEmpty {
                errorMessage = "Please enter email and password."
                return
            }
            onSuccess()
        }
    }
}

#Preview {
    LoginView()
}
