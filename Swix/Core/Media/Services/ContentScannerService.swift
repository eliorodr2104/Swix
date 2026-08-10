//
//  ContentScannerService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// The default `ContentScannerServiceProtocol`, built on `ContentScanner` and `setContentScanner`.
///
/// Most homeservers run no scanner at all, which is why an unconfigured service answers with a
/// verdict rather than an error: scanning being absent is a normal deployment, not a failure.
final class ContentScannerService: ContentScannerServiceProtocol {

    private let clientService: any ClientServiceProtocol

    private var scanner: ContentScanner?

    var isConfigured: Bool { scanner != nil }

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService
    }

    func configure(scannerURL: String) async throws {
        guard let client = clientService.sdkClient else {
            throw MediaFailure.noActiveClient
        }

        let scanner = ContentScanner(scannerUrl: scannerURL)

        await client.setContentScanner(contentScanner: scanner)

        self.scanner = scanner

        Log.media.info("Content scanner configured")
    }

    func disable() async {
        scanner = nil

        guard let client = clientService.sdkClient else {
            return
        }

        await client.setContentScanner(contentScanner: nil)
    }

    func scan(_ item: MediaItem) async throws -> ScanVerdict {
        guard let scanner, let client = clientService.sdkClient else {
            return .unavailable
        }

        let source = try MediaSourceMapper.makeMediaSource(from: item)

        do {
            return MediaScanMapper.makeVerdict(from: try await scanner.scan(client: client, mediaSource: source))
        } catch {
            if let verdict = MediaScanMapper.makeVerdict(from: error) {
                return verdict
            }

            Log.media.error("Content scan failed: \(String(reflecting: error), privacy: .public)")

            throw MediaFailure.scanFailed(SDKErrorInfo(error))
        }
    }
}
