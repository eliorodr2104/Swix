//
//  SwixApp.swift
//  Swix
//
//  Created by Eliomar on 08/08/2026.
//

import SwiftUI
import SwiftData

@main
struct SwixApp: App {
    
    @State
    private var container = CoreContainer()
    
    @Environment(\.scenePhase)
    private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(
                    \.coreContainer,
                     container
                )
                .environment(
                    \.sessionViewModel,
                     container.sessionViewModel
                )
                .environment(
                    \.loginViewModel,
                     container.loginViewModel
                )
                .task { await container.start() }
                .onChange(of: scenePhase) { _, phase in
                    container.handle(scenePhase: .init(phase))
                }

        }
        
//        .modelContainer(sharedModelContainer)
    }
}
