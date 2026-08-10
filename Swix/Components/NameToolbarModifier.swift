//
//  NameToolbarModifier.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import SwiftUI

private struct NameToolbarModifier: ViewModifier {
    
    private var name: String
    
    init(name: String) {
        self.name = name
    }
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                
                ToolbarItem(placement: .title) {
                    
                    HStack {
                        Text(name)
                            .fontWeight(.bold)
                            .fontDesign(.default)
                            .font(.largeTitle)
                        
                        Text(String(repeating: " ", count: 2))
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
    }
}

extension View {
    func withNameToolbar(_ name: String) -> some View {
        self.modifier(NameToolbarModifier(name: name))
    }
}
