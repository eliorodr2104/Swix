//
//  HomeView.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//

import SwiftUI

struct HomeView: View {
    
    @State
    private var navigation: NavigationState = .chats


    // TODO: - Move this into vm for custom search
    @State
    private var query: String = ""

    var body: some View {
        
        TabView {
            
            Tab(
                NavigationState.chats.rawValue,
                systemImage: NavigationState.chats.icon
            ) { ChatsView() }
            
            Tab(
                NavigationState.calls.rawValue,
                systemImage: NavigationState.calls.icon
            ) { EmptyView() }
            
            Tab(role: .search) {
                NavigationStack {
                    EmptyView()
                        .searchable(text: $query)
                        .tabViewSearchActivation(.searchTabSelection)
                }
            }
        }
    }
}
