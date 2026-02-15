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
    @State private var screen: AuthScreen = .splash
    /// Used for WhatsApp/Telegram-style push (forward) vs pop (back) transitions.
    @State private var isGoingBack = false
    @State private var serverConfig = ServerConfig.load()
    @State private var showServerConfig = false

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
            ContentView()
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
                    onSuccess: { goForward(to: .main) },
                    onBack: { goBack(to: .splash) }
                )
                .transition(.asymmetric(
                    insertion: isGoingBack ? .move(edge: .leading) : .move(edge: .trailing),
                    removal: isGoingBack ? .move(edge: .trailing) : .move(edge: .leading)
                ))
            case .register:
                RegisterView(
                    onSuccess: { goForward(to: .main) },
                    onBack: { goBack(to: .splash) }
                )
                .transition(.asymmetric(
                    insertion: isGoingBack ? .move(edge: .leading) : .move(edge: .trailing),
                    removal: isGoingBack ? .move(edge: .trailing) : .move(edge: .leading)
                ))
            case .main:
                EmptyView()
            }

            // Gear on top so it stays visible over splash/login/register
            VStack {
                HStack {
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
    }
}

#Preview {
    RootView()
        .modelContainer(for: Item.self, inMemory: true)
}
