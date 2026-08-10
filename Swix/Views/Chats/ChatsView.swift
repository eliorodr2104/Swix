//
//  ChatsView.swift
//  Swix
//
//  Created by Eliomar on 08/08/2026.
//

import SwiftUI

struct ChatsView: View {
    
    
    var body: some View {
        
        NavigationStack {
            ScrollView {
                
                LazyVStack(
                    alignment: .leading,
                    pinnedViews: [.sectionHeaders]
                ) {
                    
                    // TODO: - Appear if exist pinned chats
                    Section {
                        
                        Text("Important Chat")
                        
                    } header: {
                        sectionHeader("Pinned")
                    }
                    
                    
                    // TODO: - I need found modifier for hide the title when the pinned section is hidden
                    Section() {
                        
                        Text("Normal Chat")
                        
                    } header: {
                        sectionHeader("Chats")
                            .padding(.top, 24)
                    }
                }
                
            }
            .padding()
            .withProfileToolbar()
            .withNameToolbar(NavigationState.chats.rawValue)
            .toolbar {
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                                    
                    Button("Select Chats", systemImage: "checklist") {
                        print("Select chats")
                    }
                    
                    Button("New Chat", systemImage: "bubble.and.pencil") {
                        print("New chat")
                    }
                    
                }
                
                ToolbarSpacer(placement: .topBarTrailing)
            }
        }
    }
    
    private func sectionHeader(_ text: String) -> some View {
        
        Text(text)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
        
    }
}
