//
//  TileServerInfoMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("TileServerInfoMapper")
struct TileServerInfoMapperTests {

    @Test("a nil SDK advertisement maps to nil")
    func nilAdvertisementMapsToNil() {
        #expect(TileServerInfoMapper.makeTileServerInfo(from: nil) == nil)
    }

    @Test("an advertised style URL carries straight through")
    func advertisedStyleURLCarriesThrough() {
        let sdkInfo = MatrixRustSDK.TileServerInfo(mapStyleUrl: "https://tiles.example.org/style.json")

        #expect(TileServerInfoMapper.makeTileServerInfo(from: sdkInfo)?.mapStyleUrl == "https://tiles.example.org/style.json")
    }
}
