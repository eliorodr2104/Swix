//
//  NavigationState.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//

enum NavigationState: String, Hashable {
    
    case chats = "Chats"
    case calls = "Calls"
    
    var icon: String {
        
        switch self {
            case .chats: "message"
            case .calls: "phone.fill"
        }
    }
}
