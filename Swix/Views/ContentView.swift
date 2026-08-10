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
    
    @AppStorage("first_boot")
    private var isFirstBoot: Bool = true
        
    var body: some View {
        
        if isFirstBoot {
            
            NavigationStack {
                OnboardingView()
                    .navigationDestination(for: LoginState.self) { step in
                        
                        switch step {
                            case .chooseServer: ChooseServerView()
                            case .qrScaning   : EmptyView()
                            case .login       : LoginView()
                            case .signup      : EmptyView()
                        }
                        
                    }
            }
            
        } else if let scope = container?.scope {
            
            HomeView()
                .environment(
                    \.chatListViewModel,
                     scope.chatListViewModel
                )
                .environment(
                    \.sessionVerificationViewModel,
                     scope.sessionVerificationViewModel
                )
            
        } else {
            EmptyView() // LoginView()
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
