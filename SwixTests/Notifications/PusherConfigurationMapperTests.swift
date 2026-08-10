//
//  PusherConfigurationMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("PusherConfigurationMapper")
struct PusherConfigurationMapperTests {

    @Test("identifiers carry the push key and the app id, nothing else")
    func identifiersCarryPushKeyAndAppID() {
        let configuration = Self.makeConfiguration(pushKey: "abc123", appID: "org.example.swix")

        let identifiers = PusherConfigurationMapper.makeIdentifiers(from: configuration)

        #expect(identifiers.pushkey == "abc123")
        #expect(identifiers.appId == "org.example.swix")
    }

    @Test("the pusher kind always asks for eventIdOnly, never the full content")
    func kindAlwaysAsksForEventIdOnly() {
        let configuration = Self.makeConfiguration(gatewayURL: "https://push.example.org/notify", defaultPayload: "{}")

        guard case .http(let data) = PusherConfigurationMapper.makeKind(from: configuration) else {
            Issue.record("expected an http pusher kind")
            return
        }

        #expect(data.url == "https://push.example.org/notify")
        #expect(data.format == .eventIdOnly)
        #expect(data.defaultPayload == "{}")
    }

    private static func makeConfiguration(
        pushKey       : String = "push-key",
        appID         : String = "app-id",
        gatewayURL    : String = PusherConfiguration.defaultGatewayURL,
        defaultPayload: String? = PusherConfiguration.defaultPayload
    ) -> PusherConfiguration {

        PusherConfiguration(
            pushKey                 : pushKey,
            appID                   : appID,
            gatewayURL              : gatewayURL,
            appDisplayName          : "Swix",
            deviceDisplayName       : "Test Device",
            profileTag              : nil,
            language                : "en",
            defaultPayload          : defaultPayload,
            appendsToExistingPushers: false
        )
    }
}
