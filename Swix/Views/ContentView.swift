//
//  ContentView.swift
//  Swix
//
//  Created by Eliomar on 08/08/2026.
//

import SwiftUI

struct ContentView: View {
    
    @Environment(\.coreContainer)
    private var container

    @Environment(\.sessionViewModel)
    private var session

    private var isShowingSplash: Bool {
        container?.scope == nil && container?.hasStoredAccount == true
    }

    private var sessionWasRevoked: Binding<Bool> {
        Binding(
            get: { session?.sessionWasRevoked ?? false },
            set: { session?.sessionWasRevoked = $0 }
        )
    }

    var body: some View {

        Group {

            if let scope = container?.scope {

                HomeView()
                    .environment(
                        \.chatListViewModel,
                         scope.chatListViewModel
                    )
                    .environment(
                        \.sessionVerificationViewModel,
                         scope.sessionVerificationViewModel
                    )
                    .environment(
                        \.mediaService,
                         scope.mediaService
                    )

            } else if isShowingSplash {

                SplashView()
                    .transition(
                        .scale(scale: 1.75)
                        .combined(with: .opacity)
                    )
                    .zIndex(1)

            } else {

                NavigationStack {
                    OnboardingView()
                        .navigationDestination(for: LoginState.self) { step in

                            switch step {
                                case .chooseServer: ChooseServerView()
                                case .qrScaning   : EmptyView()
                                default           : EmptyView()
                            }

                        }
                }

            }
        }
        .animation(
            .smooth(duration: 0.55),
            value: isShowingSplash
        )
        .alert(
            "Session expired",
            isPresented: sessionWasRevoked
        ) {
            Button("Sign in again") { }

        } message: {
            Text("The server ended your session. Please sign in to continue.")
        }
    }
}

#Preview {
    ContentView()
//        .modelContainer(
//            for     : Item.self,
//            inMemory: true
//        )
}
