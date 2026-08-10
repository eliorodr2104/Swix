//
//  PusherConfigurationMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Splits a `PusherConfiguration` into the two shapes `Client.setPusher` asks for.
enum PusherConfigurationMapper {

    /// The pair that identifies a pusher on the account, and the only thing deleting one needs.
    static func makeIdentifiers(from configuration: PusherConfiguration) -> PusherIdentifiers {
        PusherIdentifiers(pushkey: configuration.pushKey, appId: configuration.appID)
    }

    /// The gateway description. `eventIdOnly` keeps the homeserver from putting message content in
    /// the push, which is the only honest choice for an end to end encrypted client.
    static func makeKind(from configuration: PusherConfiguration) -> PusherKind {
        .http(
            data: HttpPusherData(
                url           : configuration.gatewayURL,
                format        : .eventIdOnly,
                defaultPayload: configuration.defaultPayload
            )
        )
    }
}
