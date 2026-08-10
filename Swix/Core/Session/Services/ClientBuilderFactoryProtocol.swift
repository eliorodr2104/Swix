//
//  ClientBuilderFactoryProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Produces `ClientBuilder` instances that already carry every Swix wide decision: where the
/// encrypted stores live, how they are unlocked, and which SDK features are on.
protocol ClientBuilderFactoryProtocol {

    /// Builder for an account we are about to sign in, from whatever the user typed in the
    /// homeserver field: either a server name (`matrix.org`) or a full URL.
    func makeBuilder(
        serverNameOrHomeserverURL: String,
        storeIdentity            : SessionStoreIdentity
    ) throws -> ClientBuilder

    /// Builder for a session we already own, pinned to the homeserver that issued it.
    func makeBuilder(
        homeserverURL: String,
        storeIdentity: SessionStoreIdentity
    ) throws -> ClientBuilder
}
