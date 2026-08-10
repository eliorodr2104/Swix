//
//  AppScenePhase.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import SwiftUI


/// Mirrors SwiftUI's `ScenePhase` with a plain enum, so `SyncLifecycleController` can react to the
/// app's lifecycle without importing SwiftUI itself. The call site maps `ScenePhase` onto this value.
enum AppScenePhase {

    /// The app is in the foreground and receiving events.
    case active

    /// The app is transitioning, most often a brief interruption like the control center opening.
    case inactive

    /// The app is no longer visible.
    case background
    
    init(_ value: ScenePhase) {
        
        self = switch value {
            case .background: .background
            case .inactive  : .inactive
            case .active    : .active
            @unknown default: .inactive
        }
        
    }
}
