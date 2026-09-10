// TamaNDIApp.swift
// App — Main entry point for the TamaNDI iOS application.

import SwiftUI
import UI

@main
struct TamaNDIApp: App {

    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
                .onAppear {
                    Task {
                        await coordinator.start()
                    }
                }
        }
    }
}
