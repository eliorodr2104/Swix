//
//  TaskHandleSubscription.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK

// This file is an explicitly allowed exception to the "no MatrixRustSDK outside
// Mappers/Services/SDKBridge" rule, the same way SDKErrorInfo.swift and TracingSetup.swift are:
// it exists solely to retroactively conform the SDK's TaskHandle to our SDK-free
// CancellableSubscription protocol, so SubscriptionBag itself never needs the import.
extension TaskHandle: CancellableSubscription {}
