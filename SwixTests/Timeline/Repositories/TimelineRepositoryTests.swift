//
//  TimelineRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
import Foundation
@testable import Swix


@Suite("TimelineRepository")
struct TimelineRepositoryTests {

    @Test("start succeeds, starts the service once and clears any previous failure")
    func startSucceeds() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        #expect(service.startCallCount == 1)
        #expect(repository.failure == nil)
    }

    @Test("a start failure is wrapped into TimelineFailure")
    func startFailureIsWrapped() async {
        let service = MockTimelineService()
        service.startError = TimelineFailure.noActiveClient

        let repository = TimelineRepository(service: service)

        await repository.start()

        guard case .noActiveClient = repository.failure else {
            Issue.record("Expected .noActiveClient, got \(String(describing: repository.failure))")
            return
        }
    }

    @Test("roomID passes through from the underlying service")
    func roomIDPassesThrough() {
        let service = MockTimelineService(roomID: "!specific:example.org")
        let repository = TimelineRepository(service: service)

        #expect(repository.roomID == "!specific:example.org")
    }

    @Test("the first batch resets the whole list, the way the SDK's initial attach does")
    func initialResetReplacesTheList() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        let first = Fixtures.timelineMessage(id: "item-1", eventIdentifier: .event("$1"))
        let second = Fixtures.timelineMessage(id: "item-2", eventIdentifier: .event("$2"))

        service.emit(diffs: [.reset([first, second])])
        await Eventually.isTrue { repository.entries.count == 2 }

        #expect(repository.entries.map(\.id) == ["item-1", "item-2"])
    }

    @Test("later diff batches apply on top of the reset in order")
    func laterDiffsApplyInOrder() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        let first = Fixtures.timelineMessage(id: "item-1", eventIdentifier: .event("$1"))
        service.emit(diffs: [.reset([first])])
        await Eventually.isTrue { repository.entries.count == 1 }

        let second = Fixtures.timelineMessage(id: "item-2", eventIdentifier: .event("$2"))
        service.emit(diffs: [.pushBack(second)])
        await Eventually.isTrue { repository.entries.count == 2 }

        #expect(repository.entries.map(\.id) == ["item-1", "item-2"])
    }

    @Test("events excludes layout rows, keeping only messages and polls")
    func eventsExcludesLayoutRows() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        service.emit(diffs: [
            .reset([
                .dateSeparator(id: "sep-1", date: Date(timeIntervalSince1970: 0)),
                Fixtures.timelineMessage(id: "item-1", eventIdentifier: .event("$1")),
                .readMarker(id: "marker-1")
            ])
        ])
        await Eventually.isTrue { repository.entries.count == 3 }

        #expect(repository.entries.count == 3)
        #expect(repository.events.map(\.id) == ["item-1"])
        #expect(repository.isEmpty == false)
    }

    @Test("isEmpty is true when only layout rows are present")
    func isEmptyWithOnlyLayoutRows() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        service.emit(diffs: [.reset([.timelineStart(id: "start-1")])])
        await Eventually.isTrue { !repository.entries.isEmpty }

        #expect(repository.isEmpty == true)
    }

    @Test("paginateBackwards asks the service and respects canPaginate")
    func paginateBackwardsRespectsPaginationState() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        await repository.paginateBackwards()
        #expect(service.paginateBackwardsCallCount == 1)

        service.emit(paginationState: .paginating)
        await Eventually.isTrue { repository.paginationState == .paginating }

        await repository.paginateBackwards()
        #expect(service.paginateBackwardsCallCount == 1)

        service.emit(paginationState: .idle(hasReachedStart: true))
        await Eventually.isTrue { repository.paginationState == .idle(hasReachedStart: true) }

        await repository.paginateBackwards()
        #expect(service.paginateBackwardsCallCount == 1)

        service.emit(paginationState: .idle(hasReachedStart: false))
        await Eventually.isTrue { repository.paginationState == .idle(hasReachedStart: false) }

        await repository.paginateBackwards()
        #expect(service.paginateBackwardsCallCount == 2)
    }

    @Test("the pagination stream is mirrored onto paginationState")
    func paginationStreamUpdatesState() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        service.emit(paginationState: .paginating)
        await Eventually.isTrue { repository.paginationState == .paginating }
        #expect(repository.paginationState == .paginating)

        service.emit(paginationState: .idle(hasReachedStart: true))
        await Eventually.isTrue { repository.paginationState == .idle(hasReachedStart: true) }
        #expect(repository.paginationState == .idle(hasReachedStart: true))
    }

    @Test("a recoverable send failure wedges the queue")
    func recoverableFailureWedgesQueue() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        service.emit(sendQueueEvent: .failed(transactionID: "txn-1", reason: "offline", isRecoverable: true))
        await Eventually.isTrue { repository.isSendQueueWedged == true }

        #expect(repository.isSendQueueWedged == true)
    }

    @Test("an unrecoverable send failure leaves the queue unwedged")
    func unrecoverableFailureDoesNotWedgeQueue() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        // Nothing observable flips as a direct result of this event, so the assertion waits on
        // the entry it does touch instead of the wedge flag that stays put.
        let localEcho = Fixtures.timelineMessage(id: "item-1", eventIdentifier: .transaction("txn-1"))
        service.emit(diffs: [.reset([localEcho])])
        await Eventually.isTrue { !repository.entries.isEmpty }

        service.emit(sendQueueEvent: .failed(transactionID: "txn-1", reason: "rejected", isRecoverable: false))
        await Eventually.isTrue { repository.entries.first?.message?.sendState != nil }

        #expect(repository.isSendQueueWedged == false)
    }

    @Test("retrying and sent both clear a previously wedged queue")
    func retryingAndSentClearTheWedge() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        service.emit(sendQueueEvent: .failed(transactionID: "txn-1", reason: "offline", isRecoverable: true))
        await Eventually.isTrue { repository.isSendQueueWedged == true }
        #expect(repository.isSendQueueWedged == true)

        service.emit(sendQueueEvent: .retrying(transactionID: "txn-1"))
        await Eventually.isTrue { repository.isSendQueueWedged == false }
        #expect(repository.isSendQueueWedged == false)
    }

    @Test("a sent event reconciles the matching local echo's send state in place")
    func sentEventReconcilesLocalEcho() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        let localEcho = Fixtures.timelineMessage(id: "item-1", eventIdentifier: .transaction("txn-1"))
        service.emit(diffs: [.reset([localEcho])])
        await Eventually.isTrue { !repository.entries.isEmpty }

        service.emit(sendQueueEvent: .sent(transactionID: "txn-1", eventID: "$event1"))
        await Eventually.isTrue { repository.entries.first?.message?.sendState != nil }

        #expect(repository.entries.first?.message?.sendState == .sent(eventID: "$event1"))
        #expect(repository.entries.first?.eventIdentifier == .transaction("txn-1"))
    }

    @Test("a failed send event reconciles the matching local echo's send state")
    func failedEventReconcilesLocalEcho() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        let localEcho = Fixtures.timelineMessage(id: "item-1", eventIdentifier: .transaction("txn-1"))
        service.emit(diffs: [.reset([localEcho])])
        await Eventually.isTrue { !repository.entries.isEmpty }

        service.emit(sendQueueEvent: .failed(transactionID: "txn-1", reason: "offline", isRecoverable: true))
        await Eventually.isTrue { repository.entries.first?.message?.sendState != nil }

        #expect(
            repository.entries.first?.message?.sendState ==
            .failed(reason: "offline", isRecoverable: true)
        )
    }

    @Test("a send queue event never touches an entry with a different transaction id")
    func sendQueueEventLeavesOtherEntriesAlone() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        let localEcho = Fixtures.timelineMessage(id: "item-1", eventIdentifier: .transaction("txn-1"))
        let remoteEcho = Fixtures.timelineMessage(id: "item-2", eventIdentifier: .event("$2"))
        service.emit(diffs: [.reset([localEcho, remoteEcho])])
        await Eventually.isTrue { repository.entries.count == 2 }

        service.emit(sendQueueEvent: .sent(transactionID: "txn-1", eventID: "$event1"))
        await Eventually.isTrue { repository.entries.first?.message?.sendState != nil }

        #expect(repository.entries.last?.message?.sendState == nil)
    }

    @Test("upload progress is tracked by its media event id")
    func uploadProgressIsTracked() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()

        service.emit(sendQueueEvent: .uploadProgress(relatedTo: "media-1", fraction: 0.5))
        await Eventually.isTrue { repository.uploadProgress["media-1"] != nil }

        #expect(repository.uploadProgress["media-1"] == 0.5)
    }

    @Test("shutdown releases the underlying service")
    func shutdownReleasesService() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)

        await repository.start()
        repository.shutdown()

        #expect(service.shutdownCallCount == 1)
    }
}
