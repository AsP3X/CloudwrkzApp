//
//  AccountSettingsView.swift
//  Cloudwrkz
//
//  Account settings: notifications, appearance, security, server, data & privacy.
//  Fancy, liquid glass, modern enterprise. Opened from Profile → Account settings.
//

import SwiftUI

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showServerConfig = false

    @State private var notificationsEnabled = AccountSettingsStorage.notificationsEnabled
    @State private var emailDigestEnabled = AccountSettingsStorage.emailDigestEnabled
    @State private var appearanceSelection = AccountSettingsStorage.appearance
    @State private var biometricLockEnabled = AccountSettingsStorage.biometricLockEnabled

    @State private var serverConfig = ServerConfig.load()

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
                        notificationsSection
                        appearanceSection
                        securitySection
                        serverSection
                        dataPrivacySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Account Settings")
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
            .onAppear {
                loadPreferences()
            }
            .onChange(of: notificationsEnabled) { _, v in AccountSettingsStorage.notificationsEnabled = v }
            .onChange(of: emailDigestEnabled) { _, v in AccountSettingsStorage.emailDigestEnabled = v }
            .onChange(of: appearanceSelection) { _, v in AccountSettingsStorage.appearance = v }
            .onChange(of: biometricLockEnabled) { _, v in AccountSettingsStorage.biometricLockEnabled = v }
            .sheet(isPresented: $showServerConfig) {
                ServerConfigView(config: $serverConfig)
            }
        }
    }

    private func loadPreferences() {
        notificationsEnabled = AccountSettingsStorage.notificationsEnabled
        emailDigestEnabled = AccountSettingsStorage.emailDigestEnabled
        appearanceSelection = AccountSettingsStorage.appearance
        biometricLockEnabled = AccountSettingsStorage.biometricLockEnabled
        serverConfig = ServerConfig.load()
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(CloudwrkzColors.neutral500)
            .padding(.bottom, 8)
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Notifications")
            VStack(spacing: 0) {
                settingsToggleRow(
                    icon: "bell.fill",
                    title: "Push notifications",
                    subtitle: "Alerts and updates"
                ) {
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .tint(CloudwrkzColors.primary400)
                }
                settingsDivider
                settingsToggleRow(
                    icon: "envelope.fill",
                    title: "Email digest",
                    subtitle: "Daily or weekly summary"
                ) {
                    Toggle("", isOn: $emailDigestEnabled)
                        .labelsHidden()
                        .tint(CloudwrkzColors.primary400)
                }
            }
            .padding(16)
            .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Appearance")
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(CloudwrkzColors.neutral500)
                    Text("Theme")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CloudwrkzColors.neutral400)
                }
                Picker("Theme", selection: $appearanceSelection) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .tint(CloudwrkzColors.primary400)
            }
            .padding(20)
            .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Security")
            VStack(spacing: 0) {
                settingsActionRow(
                    icon: "lock.rotation",
                    title: "Change password",
                    subtitle: "Update your password"
                ) {
                    // Placeholder: open change-password flow or URL
                }
                settingsDivider
                settingsToggleRow(
                    icon: "faceid",
                    title: "Biometric lock",
                    subtitle: BiometricService.isAvailable ? "\(BiometricService.biometricTypeName) required when returning to app" : "Not available on this device"
                ) {
                    Toggle("", isOn: $biometricLockEnabled)
                        .labelsHidden()
                        .tint(CloudwrkzColors.primary400)
                        .disabled(!BiometricService.isAvailable)
                }
            }
            .padding(16)
            .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
        }
    }

    // MARK: - Server

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Server")
            AccountSettingsRow(
                icon: "server.rack",
                title: "Server configuration",
                subtitle: serverConfig.tenant == .official ? "Official Cloudwrkz" : (serverConfig.serverDomain.isEmpty ? "On‑prem" : serverConfig.serverDomain)
            ) {
                showServerConfig = true
            }
        }
    }

    // MARK: - Data & privacy

    private var dataPrivacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Data & Privacy")
            VStack(spacing: 0) {
                AccountSettingsRow(
                    icon: "trash",
                    title: "Clear local cache",
                    subtitle: "Free up space"
                ) {
                    // Placeholder: clear caches
                }
                settingsDivider
                AccountSettingsRow(
                    icon: "hand.raised.fill",
                    title: "Privacy policy",
                    subtitle: "How we handle your data"
                ) {
                    // Placeholder: open URL
                }
            }
            .padding(16)
            .glassPanel(cornerRadius: 20, tint: CloudwrkzColors.primary500, tintOpacity: 0.04)
        }
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 1)
    }

    /// Same layout as settingsToggleRow but tappable with chevron; pairs visually with toggle rows.
    private func settingsActionRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(CloudwrkzColors.primary400)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CloudwrkzColors.neutral100)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(CloudwrkzColors.neutral500)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsToggleRow<Trailing: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(CloudwrkzColors.primary400)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CloudwrkzColors.neutral100)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CloudwrkzColors.neutral500)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Glass row (liquid glass, matches ProfileView / ProfileMenuPopoverView)

private struct AccountSettingsRow: View {
    var icon: String
    var title: String
    var subtitle: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(CloudwrkzColors.primary400)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CloudwrkzColors.neutral100)
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
            .contentShape(Rectangle())
            .background(settingsRowGlass)
        }
        .buttonStyle(AccountSettingsRowButtonStyle())
    }

    private var settingsRowGlass: some View {
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

private struct AccountSettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    AccountSettingsView()
}
