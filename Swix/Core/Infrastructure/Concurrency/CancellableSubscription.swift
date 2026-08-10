//
//  CancellableSubscription.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Anything that can be torn down with a single, synchronous `cancel()` call.
///
/// This exists so `Infrastructure/Concurrency` never has to import MatrixRustSDK: the SDK's
/// `TaskHandle` is made to conform elsewhere (`TaskHandleSubscription.swift`), keeping the
/// import boundary enforceable by a plain grep.
protocol CancellableSubscription {
    func cancel()
}
