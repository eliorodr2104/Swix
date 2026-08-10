//
//  RoomProviding.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Looks up a joined room by id through whatever is currently driving sync.
///
/// SERVICE LAYER ONLY: this hands back the raw SDK `Room`, which repositories and view models must
/// never see. It exists so the Timeline and Calls services can reach a room without depending on
/// the whole of `SyncCoordinatorProtocol`, keeping the declared cross feature dependency as narrow
/// as the layering rule allows.
protocol RoomProviding {

    /// Looks up a room the account has joined. Throws `SyncFailure.notStarted` before the first
    /// `start()`, and whatever the SDK raises if the id is unknown to the room list.
    func room(withId roomID: String) throws -> Room
}
