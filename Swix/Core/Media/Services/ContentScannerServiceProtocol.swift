//
//  ContentScannerServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Runs media past the deployment's content scanning proxy, when there is one.
protocol ContentScannerServiceProtocol {

    /// Whether a scanner is currently installed on the live client.
    var isConfigured: Bool { get }

    /// Points the client at `scannerURL` and keeps the scanner for later scans.
    func configure(scannerURL: String) async throws

    /// Removes the scanner from the client, so media is fetched directly again.
    func disable() async

    /// Asks the scanner about `item`, answering `unavailable` when no scanner is configured.
    func scan(_ item: MediaItem) async throws -> ScanVerdict
}
