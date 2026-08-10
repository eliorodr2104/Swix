//
//  TracingSetup.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// One-time bootstrap of the SDK's own tracing subsystem, required before any `Client` is built.
///
/// This is an explicitly allowed exception to the "no MatrixRustSDK outside
/// Mappers/Services/SDKBridge" rule, alongside SDKErrorInfo.swift.
enum TracingSetup {

    // A lazily initialized static stored property runs its initializer exactly once, which is
    // exactly the "call initPlatform a single time, no matter how often this is invoked" contract.
    private static let didInitialize: Void = {
        do {
            try initPlatform(
                config                    : configuration,
                useLightweightTokioRuntime: false
            )
            
        } catch {
            Log.infrastructure.fault(
                "initPlatform failed: \(String(reflecting: error), privacy: .public)"
            )
        }
    }()

    /// Runs the SDK's tracing bootstrap if it has not run yet. Safe to call from every entry
    /// point that might be first (app launch, background refresh, NSE) without double init.
    static func ensureInitialized() {
        _ = didInitialize
    }

    /// The fixed tracing setup Swix boots the SDK with: errors only, straight to the system log,
    /// no file sink and no Sentry, since this app wires its own `os.Logger` categories instead.
    private static var configuration: TracingConfiguration {
        TracingConfiguration(
            logLevel             : .error,
            traceLogPacks        : [],
            extraTargets         : [],
            writeToStdoutOrSystem: true,
            writeToFiles         : nil,
            sentryConfig         : nil
        )
    }
}
