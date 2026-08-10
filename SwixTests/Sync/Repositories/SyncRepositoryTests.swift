//
//  SyncRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("SyncRepository")
struct SyncRepositoryTests {

    @Test("start succeeds, starts the coordinator once and clears any previous failure")
    func startSucceeds() async {
        let coordinator = MockSyncCoordinator()
        let repository = SyncRepository(coordinator: coordinator)

        await repository.start()

        #expect(coordinator.startCallCount == 1)
        #expect(repository.failure == nil)
    }

    @Test("a coordinator failure that is already a SyncFailure is stored as is")
    func startFailureAlreadyTyped() async {
        let coordinator = MockSyncCoordinator()
        coordinator.startError = SyncFailure.noActiveClient

        let repository = SyncRepository(coordinator: coordinator)

        await repository.start()

        #expect(repository.syncState == .failed)

        guard case .noActiveClient = repository.failure else {
            Issue.record("Expected .noActiveClient, got \(String(describing: repository.failure))")
            return
        }
    }

    @Test("an untyped coordinator failure is wrapped as startFailed")
    func startFailureWrapsUnknownError() async {
        struct DummyError: Error {}

        let coordinator = MockSyncCoordinator()
        coordinator.startError = DummyError()

        let repository = SyncRepository(coordinator: coordinator)

        await repository.start()

        #expect(repository.syncState == .failed)

        guard case .startFailed = repository.failure else {
            Issue.record("Expected .startFailed, got \(String(describing: repository.failure))")
            return
        }
    }

    @Test("the coordinator's state stream is mirrored onto syncState")
    func stateStreamUpdatesSyncState() async {
        let coordinator = MockSyncCoordinator()
        let repository = SyncRepository(coordinator: coordinator)

        await repository.start()

        coordinator.emit(state: .running)
        await Eventually.isTrue { repository.syncState == .running }
        #expect(repository.syncState == .running)

        coordinator.emit(state: .offline)
        await Eventually.isTrue { repository.syncState == .offline }
        #expect(repository.syncState == .offline)
    }

    @Test("the coordinator's indicator stream is mirrored onto isShowingSyncIndicator")
    func indicatorStreamUpdatesIndicator() async {
        let coordinator = MockSyncCoordinator()
        let repository = SyncRepository(coordinator: coordinator)

        await repository.start()

        coordinator.emit(indicator: .visible)
        await Eventually.isTrue { repository.isShowingSyncIndicator == true }
        #expect(repository.isShowingSyncIndicator == true)

        coordinator.emit(indicator: .hidden)
        await Eventually.isTrue { repository.isShowingSyncIndicator == false }
        #expect(repository.isShowingSyncIndicator == false)
    }

    @Test("stop pauses the coordinator without shutting it down")
    func stopPausesCoordinator() async {
        let coordinator = MockSyncCoordinator()
        let repository = SyncRepository(coordinator: coordinator)

        await repository.start()
        await repository.stop()

        #expect(coordinator.stopCallCount == 1)
        #expect(coordinator.shutdownCallCount == 0)
    }

    @Test("shutdown releases the coordinator")
    func shutdownReleasesCoordinator() async {
        let coordinator = MockSyncCoordinator()
        let repository = SyncRepository(coordinator: coordinator)

        await repository.start()
        repository.shutdown()

        #expect(coordinator.shutdownCallCount == 1)
    }

    @Test("calling start twice starts the coordinator again without crashing")
    func startTwiceIsSafe() async {
        let coordinator = MockSyncCoordinator()
        let repository = SyncRepository(coordinator: coordinator)

        await repository.start()
        await repository.start()

        #expect(coordinator.startCallCount == 2)

        coordinator.emit(state: .running)
        await Eventually.isTrue { repository.syncState == .running }
        #expect(repository.syncState == .running)
    }
}
