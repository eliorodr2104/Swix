//
//  MediaScanMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("MediaScanMapper")
struct MediaScanMapperTests {

    @Test("a clean response maps to clean, carrying the scanner's own info")
    func cleanResponseMapsToClean() {
        let response = MediaScanResponse(clean: true, info: "No threats found")

        #expect(MediaScanMapper.makeVerdict(from: response) == .clean(info: "No threats found"))
    }

    @Test("a dirty response maps to infected, carrying the scanner's own info")
    func dirtyResponseMapsToInfected() {
        let response = MediaScanResponse(clean: false, info: "Malware detected")

        #expect(MediaScanMapper.makeVerdict(from: response) == .infected(info: "Malware detected"))
    }

    @Test("an error unrelated to the content scanner recovers no verdict")
    func unrelatedErrorRecoversNoVerdict() {
        struct SomeOtherError: Error {}

        #expect(MediaScanMapper.makeVerdict(from: SomeOtherError()) == nil)
    }

    @Test("a media-not-clean scanner error recovers as infected")
    func mediaNotCleanErrorRecoversAsInfected() {
        let error = ClientError.ContentScanner(reason: .mcsMediaNotClean, info: "Malware detected")

        #expect(MediaScanMapper.makeVerdict(from: error) == .infected(info: "Malware detected"))
    }

    @Test("a mime-type-forbidden scanner error recovers as infected")
    func mimeTypeForbiddenErrorRecoversAsInfected() {
        let error = ClientError.ContentScanner(reason: .mcsMimeTypeForbidden, info: "File type is not allowed")

        #expect(MediaScanMapper.makeVerdict(from: error) == .infected(info: "File type is not allowed"))
    }

    @Test("any other scanner error recovers no verdict, leaving it to be reported as a failure")
    func otherScannerErrorRecoversNoVerdict() {
        let error = ClientError.ContentScanner(reason: .mcsMediaRequestFailed, info: "Timed out")

        #expect(MediaScanMapper.makeVerdict(from: error) == nil)
    }
}
