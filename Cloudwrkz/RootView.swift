//
//  RootView.swift
//  Cloudwrkz
//
//  Flow: Splash → Login / Register → Main. Liquid glass only.
//

import SwiftUI
import SwiftData

enum AuthScreen {
    case splash
    case login
    case register
    case main
}

struct RootView: View {
    @State private var screen: AuthScreen = AuthTokenStorage.getToken() != nil ? .main : .splash
    /// Used for WhatsApp/Telegram-style push (forward) vs pop (back) transitions.
    @State private var isGoingBack = false
    @State private var serverConfig = ServerConfig.load()
    @State private var showServerConfig = false
    @State private var showHealthStatus = false

    private let pushPopAnimation = Animation.easeInOut(duration: 0.32)

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

    var body: some View {
        ZStack {
            ContentView(
                showServerConfig: $showServerConfig,
                onLogout: {
                    AuthTokenStorage.clear()
                    UserProfileStorage.clear()
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
                    TenantStatusView(config: serverConfig, onTap: { showHealthStatus = true })
                        .padding(.leading, 12)
                        .padding(.top, 12)
                    Spacer()
                    Button(action: { showServerConfig = true }) {
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
        }
        .animation(pushPopAnimation, value: screen)
        .sheet(isPresented: $showServerConfig) {
            ServerConfigView(config: $serverConfig)
        }
        .sheet(isPresented: $showHealthStatus) {
            ServerHealthStatusView(config: serverConfig)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Item.self, inMemory: true)
}
