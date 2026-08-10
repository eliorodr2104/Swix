//
//  ProfileToolbarModifier.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import SwiftUI

struct ProfileToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                
                ToolbarItem(placement: .topBarTrailing) {
                    
                    Menu {
                        
                    } label: {
                        
                        Text("E")
                        
                    }
                    .clipShape(.circle)
                    
                }
            }
    }
}

extension View {
    func withProfileToolbar() -> some View {
        self.modifier(ProfileToolbarModifier())
    }
}
