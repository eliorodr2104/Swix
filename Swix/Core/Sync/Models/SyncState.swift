//
//  SyncState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// High level state of the sync engine, expressed as a small domain enum so the rest of Core never
/// has to import MatrixRustSDK just to read it.
///
/// `failed` stands in for the SDK's own `.error` case: the app never treats a sync error as fatal on
/// its own, so the repository is free to decide whether it is worth surfacing.
enum SyncState: Equatable {

    /// The sync service exists but has never been started.
    case idle

    /// Sync is live and the room list is up to date with the server.
    case running

    /// Sync was stopped for good, most often because the client itself was dropped.
    case terminated

    /// The device has no connectivity right now; sync will resume on its own once it returns.
    case offline

    /// The last cycle raised an error the SDK could not recover from by itself.
    case failed
}
