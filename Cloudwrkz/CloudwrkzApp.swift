//
//  CloudwrkzApp.swift
//  Cloudwrkz
//
//  Created by Niklas Vorberg on 13.02.26.
//

import SwiftUI
import SwiftData

@main
struct CloudwrkzApp: App {
    @AppStorage("cloudwrkz.account.appearance") private var appearance: String = "system"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private var resolvedColorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(resolvedColorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
