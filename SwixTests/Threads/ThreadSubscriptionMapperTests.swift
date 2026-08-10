//
//  ThreadSubscriptionMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


@Suite("ThreadSubscriptionMapper")
struct ThreadSubscriptionMapperTests {

    @Test("an absent subscription maps to unsubscribed, never unknown")
    func absentSubscriptionMapsToUnsubscribed() {
        #expect(ThreadSubscriptionMapper.makeState(from: nil) == .unsubscribed)
    }

    @Test("a manual subscription maps with isAutomatic false")
    func manualSubscriptionMapsToSubscribed() {
        let subscription = ThreadSubscription(automatic: false)

        #expect(ThreadSubscriptionMapper.makeState(from: subscription) == .subscribed(isAutomatic: false))
    }

    @Test("an automatic subscription maps with isAutomatic true")
    func automaticSubscriptionMapsToSubscribed() {
        let subscription = ThreadSubscription(automatic: true)

        #expect(ThreadSubscriptionMapper.makeState(from: subscription) == .subscribed(isAutomatic: true))
    }
}
