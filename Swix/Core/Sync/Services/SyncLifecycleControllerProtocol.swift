//
//  SyncLifecycleControllerProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Starts and stops sync as the app moves between foreground and background.
protocol SyncLifecycleControllerProtocol {

    /// Reacts to a new scene phase. Safe to call repeatedly with the same phase.
    func handle(scenePhase: AppScenePhase)

    /// Cancels any pending background stop. Called once, when the session ends.
    func invalidate()
}
