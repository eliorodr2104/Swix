//
//  PresenceStateMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("PresenceStateMapper")
struct PresenceStateMapperTests {

    @Test("every domain case maps to its identically named SDK case")
    func everyCaseMapsToItsSDKCounterpart() {
        let pairs: [(Swix.PresenceState, MatrixRustSDK.PresenceState)] = [
            (.online, .online),
            (.offline, .offline),
            (.unavailable, .unavailable)
        ]

        for (domainState, sdkState) in pairs {
            #expect(PresenceStateMapper.makeSDKPresenceState(from: domainState) == sdkState)
        }
    }
}
