//
//  RootView.swift
//  Cloudwrkz
//
//  Flow: Splash → Login / Register → Main. Liquid glass only.
//

import SwiftUI
import SwiftData
import UIKit

enum AuthScreen {
    case splash
    case login
    case register
    case main
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var screen: AuthScreen = AuthTokenStorage.getToken() != nil ? .main : .splash
    /// Used for WhatsApp/Telegram-style push (forward) vs pop (back) transitions.
    @State private var isGoingBack = false
    @State private var serverConfig = ServerConfig.load()
    @State private var showServerConfig = false
    @State private var showHealthStatus = false
    @State private var pendingServerConfigAfterDismiss = false
    @State private var pendingHealthStatusAfterDismiss = false
    /// When true, main content is covered by biometric lock overlay until Face ID / Touch ID succeeds.
    @State private var isAppLocked = false
    @State private var isEvaluatingBiometric = false
    /// Timer that periodically validates the session while the user is on the main screen.
    @State private var sessionCheckTimer: Timer?
    /// When true, the session-expired overlay is shown over everything.
    @State private var showSessionExpired = false

    private let pushPopAnimation = Animation.easeInOut(duration: 0.32)
    private let sessionCheckInterval: TimeInterval = 30

    private func goForward(to newScreen: AuthScreen) {
        isGoingBack = false
        withAnimation(pushPopAnimation) { screen = newScreen }
    }

    private func goBack(to newScreen: AuthScreen) {
        isGoingBack = true
        DispatchQueue.main.async {
            withAnimation(pushPopAnimation) { screen = newScreen }
        }
    }

    /// Removes all user-related data and cache on logout.
    private func clearAllUserDataAndCache() {
        // SwiftData: delete all persisted models (e.g. Item)
        let descriptor = FetchDescriptor<Item>()
        let items = (try? modelContext.fetch(descriptor)) ?? []
        for item in items {
            modelContext.delete(item)
        }
        try? modelContext.save()

        AuthTokenStorage.clear()
        UserProfileStorage.clear()
        AccountSettingsStorage.clear()
        LocalCacheService.clearAll()
    }

    var body: some View {
        ZStack {
            ContentView(
                isMainVisible: screen == .main,
                showServerConfig: $showServerConfig,
                onLogout: {
                    clearAllUserDataAndCache()
                    withAnimation(pushPopAnimation) { screen = .splash }
                }
            )
            .opacity(screen == .main ? 1 : 0)

            switch screen {
            case .splash:
                SplashView(
                    onLogin: { goForward(to: .login) },
                    onRegister: { goForward(to: .register) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
            case .login:
                LoginView(
                    serverConfig: serverConfig,
                    onSuccess: { goForward(to: .main) },
                    onBack: { goBack(to: .splash) }
                )
                .transition(.asymmetric(
                    insertion: isGoingBack ? .move(edge: .leading) : .move(edge: .trailing),
                    removal: isGoingBack ? .move(edge: .trailing) : .move(edge: .leading)
                ))
            case .register:
                RegisterView(
                    serverConfig: serverConfig,
                    onSuccess: { goForward(to: .login) },
                    onBack: { goBack(to: .splash) }
                )
                .transition(.asymmetric(
                    insertion: isGoingBack ? .move(edge: .leading) : .move(edge: .trailing),
                    removal: isGoingBack ? .move(edge: .trailing) : .move(edge: .leading)
                ))
            case .main:
                EmptyView()
            }

            // Tenant status and gear over splash/login/register.
            // When back arrow is visible (login/register), leave 44pt for it and put health to the right; otherwise health on the left.
            VStack {
                HStack(spacing: 0) {
                    if screen == .login || screen == .register {
                        Color.clear
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .allowsHitTesting(false)
                    }
                    TenantStatusView(config: serverConfig, onTap: { requestHealthStatus() })
                        .padding(.leading, 12)
                        .padding(.top, 12)
                    Spacer()
                    Button(action: { requestServerConfig() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(CloudwrkzColors.neutral100)
                            .frame(width: 44, height: 44)
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 12)
                }
                Spacer()
            }
            .allowsHitTesting(screen != .main)
            .opacity(screen == .main ? 0 : 1)

            // Biometric lock overlay when app returned from background and user is on main.
            if screen == .main, isAppLocked, !showSessionExpired {
                BiometricLockOverlayView(
                    onRetry: { await tryUnlockWithBiometric() },
                    isEvaluating: isEvaluatingBiometric
                )
                .transition(.opacity)
                .zIndex(1)
                .task { await tryUnlockWithBiometric() }
            }

            // Session-expired overlay – shown above everything when session is revoked remotely.
            if showSessionExpired {
                SessionExpiredOverlayView {
                    withAnimation(pushPopAnimation) {
                        showSessionExpired = false
                        screen = .splash
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .animation(pushPopAnimation, value: screen)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background, screen == .main, AccountSettingsStorage.biometricLockEnabled {
                isAppLocked = true
            }
            if newPhase == .active, screen == .main {
                validateSession()
                startSessionCheckTimer()
            }
            if newPhase == .background || newPhase == .inactive {
                stopSessionCheckTimer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Fallback: scenePhase can be unreliable; ensure we lock when app actually enters background
            if screen == .main, AccountSettingsStorage.biometricLockEnabled {
                isAppLocked = true
            }
        }
        .onChange(of: screen) { _, newScreen in
            if newScreen != .main {
                isAppLocked = false
                stopSessionCheckTimer()
            } else {
                validateSession()
                startSessionCheckTimer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
            guard screen == .main, !showSessionExpired else { return }
            stopSessionCheckTimer()
            clearAllUserDataAndCache()
            isAppLocked = false
            withAnimation(.easeOut(duration: 0.35)) {
                showSessionExpired = true
            }
        }
        .sheet(isPresented: $showServerConfig, onDismiss: {
            if pendingHealthStatusAfterDismiss {
                pendingHealthStatusAfterDismiss = false
                showHealthStatus = true
            }
        }) {
            ServerConfigView(config: $serverConfig)
        }
        .sheet(isPresented: $showHealthStatus, onDismiss: {
            if pendingServerConfigAfterDismiss {
                pendingServerConfigAfterDismiss = false
                showServerConfig = true
            }
        }) {
            ServerHealthStatusView(config: serverConfig)
        }
    }

    private func requestServerConfig() {
        if showHealthStatus {
            pendingServerConfigAfterDismiss = true
            showHealthStatus = false
        } else {
            showServerConfig = true
        }
    }

    private func requestHealthStatus() {
        if showServerConfig {
            pendingHealthStatusAfterDismiss = true
            showServerConfig = false
        } else {
            showHealthStatus = true
        }
    }

    /// Calls the /me endpoint to verify the session is still valid.
    /// If the server returns 401, `SessionExpiredNotifier` fires and RootView's
    /// `.onReceive(.sessionExpired)` handles the logout automatically.
    private func validateSession() {
        guard screen == .main, AuthTokenStorage.getToken() != nil else { return }
        Task {
            let config = ServerConfig.load()
            _ = await AuthService.fetchCurrentUser(config: config)
        }
    }

    private func startSessionCheckTimer() {
        stopSessionCheckTimer()
        let timer = Timer.scheduledTimer(withTimeInterval: sessionCheckInterval, repeats: true) { _ in
            validateSession()
        }
        sessionCheckTimer = timer
    }

    private func stopSessionCheckTimer() {
        sessionCheckTimer?.invalidate()
        sessionCheckTimer = nil
    }

    /// Runs Face ID / Touch ID. On success, clears app lock. Call when overlay appears or user taps Unlock.
    private func tryUnlockWithBiometric() async {
        guard AccountSettingsStorage.biometricLockEnabled, BiometricService.isAvailable else {
            await MainActor.run { isAppLocked = false }
            return
        }
        await MainActor.run { isEvaluatingBiometric = true }
        // Brief delay so overlay is fully presented before system Face ID UI appears
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        let success = await BiometricService.evaluate(reason: "Unlock Cloudwrkz")
        await MainActor.run {
            isEvaluatingBiometric = false
            if success { isAppLocked = false }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Item.self, inMemory: true)
}
