//
//  OwnBeaconMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("OwnBeaconMapper")
struct OwnBeaconMapperTests {

    @Test("every field carries straight across")
    func everyFieldCarriesAcross() {
        let update = BeaconInfoUpdate(roomId: "!room:example.org", eventId: "$beacon1", live: true)

        let mapped = OwnBeaconMapper.makeUpdate(from: update)

        #expect(mapped.roomID == "!room:example.org")
        #expect(mapped.eventID == "$beacon1")
        #expect(mapped.isLive == true)
    }
}
