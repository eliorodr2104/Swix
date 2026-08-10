//
//  AccountDataRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import Testing
@testable import Swix


@Suite("AccountDataRepository")
struct AccountDataRepositoryTests {

    private struct Widget: Codable, Equatable {
        let name: String
    }

    @Test("refresh caches the raw value the service fetched")
    func refreshCachesRawValue() async {
        let service = MockAccountDataService()
        let eventType = AccountDataEventType.custom("org.example.widget")

        service.globalValuesByType[eventType.rawValue] = try! JSONEncoder().encode(Widget(name: "gizmo"))

        let repository = AccountDataRepository(service: service)

        await repository.refresh(eventType: eventType)

        #expect(repository.value(for: eventType, as: Widget.self) == Widget(name: "gizmo"))
        #expect(repository.failure == nil)
    }

    @Test("value(for:as:) answers nil when nothing was ever cached")
    func valueAnswersNilWhenUncached() {
        let service = MockAccountDataService()
        let repository = AccountDataRepository(service: service)

        #expect(repository.value(for: .custom("org.example.widget"), as: Widget.self) == nil)
    }

    @Test("set writes through the homeserver and updates the cache immediately")
    func setUpdatesCacheImmediately() async {
        let service = MockAccountDataService()
        let eventType = AccountDataEventType.custom("org.example.widget")
        let repository = AccountDataRepository(service: service)

        await repository.set(eventType: eventType, content: Widget(name: "gizmo"))

        #expect(service.setGlobalCalls.count == 1)
        #expect(repository.value(for: eventType, as: Widget.self) == Widget(name: "gizmo"))
    }

    @Test("a fetch failure is recorded and does not touch the cache")
    func fetchFailureIsRecorded() async {
        let service = MockAccountDataService()

        service.fetchError = AccountDataFailure.fetchFailed(Fixtures.sdkErrorInfo())

        let repository = AccountDataRepository(service: service)

        await repository.refresh(eventType: .custom("org.example.widget"))

        #expect(repository.failure != nil)
        #expect(repository.values.isEmpty)
    }

    @Test("observe keeps the cache in step with later changes, and only subscribes once")
    func observeKeepsCacheInStep() async {
        let service = MockAccountDataService()
        let eventType = AccountDataEventType.custom("org.example.widget")
        let repository = AccountDataRepository(service: service)

        repository.observe(eventType: eventType)
        repository.observe(eventType: eventType)

        #expect(service.observedGlobalTypes.count == 1)

        service.yieldGlobal(try! JSONEncoder().encode(Widget(name: "updated")), eventType: eventType)

        await Eventually.isTrue { repository.value(for: eventType, as: Widget.self) == Widget(name: "updated") }

        #expect(repository.value(for: eventType, as: Widget.self) == Widget(name: "updated"))
    }

    @Test("an unobservable event type records the failure rather than crashing")
    func unobservableEventTypeRecordsFailure() {
        let service = MockAccountDataService()

        service.observeGlobalError = AccountDataFailure.unobservable(eventType: "org.example.widget")

        let repository = AccountDataRepository(service: service)

        repository.observe(eventType: .custom("org.example.widget"))

        #expect(repository.failure != nil)
    }

    @Test("shutdown releases the service and forgets which event types were observed")
    func shutdownReleasesService() {
        let service = MockAccountDataService()
        let repository = AccountDataRepository(service: service)

        repository.observe(eventType: .custom("org.example.widget"))
        repository.shutdown()

        #expect(service.shutdownCallCount == 1)
    }
}
