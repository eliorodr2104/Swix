//
//  LocationPayloadMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("LocationPayloadMapper")
struct LocationPayloadMapperTests {

    @Test("the fallback body uses the sender's own description when there is one")
    func fallbackBodyUsesDescriptionWhenPresent() {
        let payload = LocationPayload(latitude: 51.5, longitude: -0.1, description: "The office")

        #expect(LocationPayloadMapper.makeBody(from: payload) == "The office")
    }

    @Test("the fallback body falls back to the bare geo URI without a description")
    func fallbackBodyFallsBackToGeoURI() {
        let payload = LocationPayload(latitude: 51.5, longitude: -0.1)

        #expect(LocationPayloadMapper.makeBody(from: payload) == "Location: geo:51.5,-0.1")
    }

    @Test("a well formed geo URI parses back into latitude and longitude")
    func wellFormedGeoURIParses() {
        let content = LocationContent(body: "Location", geoUri: "geo:51.5,-0.1", description: "Home", zoomLevel: 15, asset: .pin)

        let payload = LocationPayloadMapper.makePayload(from: content)

        #expect(payload?.latitude == 51.5)
        #expect(payload?.longitude == -0.1)
        #expect(payload?.description == "Home")
        #expect(payload?.zoomLevel == 15)
    }

    @Test("an uncertainty parameter after the semicolon is ignored")
    func uncertaintyParameterIsIgnored() {
        let content = LocationContent(body: "Location", geoUri: "geo:51.5,-0.1;u=35", description: nil, zoomLevel: nil, asset: .pin)

        let payload = LocationPayloadMapper.makePayload(from: content)

        #expect(payload?.latitude == 51.5)
        #expect(payload?.longitude == -0.1)
    }

    @Test("a malformed geo URI maps to nil rather than crashing")
    func malformedGeoURIMapsToNil() {
        let content = LocationContent(body: "Location", geoUri: "not-a-geo-uri", description: nil, zoomLevel: nil, asset: .pin)

        #expect(LocationPayloadMapper.makePayload(from: content) == nil)
    }
}
