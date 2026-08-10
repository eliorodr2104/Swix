//
//  ChatViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("ChatViewModel")
struct ChatViewModelTests {

    @Test("sendMessage sends the composer text and clears the composer")
    func sendMessageSendsAndClears() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)
        let viewModel = ChatViewModel(repository: repository)

        await viewModel.start()

        viewModel.composerText = "  Hello there  "

        await viewModel.sendMessage()

        #expect(service.sentMessages.count == 1)
        #expect(service.sentMessages.first?.markdown == "Hello there")
        #expect(service.sentMessages.first?.replyToEventID == nil)
        #expect(viewModel.composerText.isEmpty)
    }

    @Test("sendMessage attaches the pending reply and clears it afterward")
    func sendMessageAttachesReply() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)
        let viewModel = ChatViewModel(repository: repository)

        await viewModel.start()

        viewModel.replyToEventID = "$original"
        viewModel.composerText = "Reply text"

        await viewModel.sendMessage()

        #expect(service.sentMessages.first?.replyToEventID == "$original")
        #expect(viewModel.replyToEventID == nil)
    }

    @Test("sendMessage with an editing entry set edits instead of sending")
    func sendMessageEditsWhenEditing() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)
        let viewModel = ChatViewModel(repository: repository)

        await viewModel.start()

        viewModel.editingEntryID = .event("$original")
        viewModel.composerText = "Corrected text"

        await viewModel.sendMessage()

        #expect(service.sentMessages.isEmpty)
        #expect(service.edits.count == 1)
        #expect(service.edits.first?.entryID == .event("$original"))
        #expect(service.edits.first?.markdown == "Corrected text")
        #expect(viewModel.editingEntryID == nil)
    }

    @Test("sendMessage with a blank composer does nothing")
    func sendMessageIgnoresBlankText() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)
        let viewModel = ChatViewModel(repository: repository)

        await viewModel.start()

        viewModel.composerText = "   "

        await viewModel.sendMessage()

        #expect(service.sentMessages.isEmpty)
        #expect(service.edits.isEmpty)
        #expect(viewModel.composerText == "   ")
    }

    @Test("a send failure surfaces a user facing failure")
    func sendMessageFailureSurfaces() async {
        let service = MockTimelineService()
        service.sendError = TimelineFailure.sendFailed(Fixtures.sdkErrorInfo(kind: .network))

        let repository = TimelineRepository(service: service)
        let viewModel = ChatViewModel(repository: repository)

        await viewModel.start()

        viewModel.composerText = "Hello"
        await viewModel.sendMessage()

        #expect(viewModel.failure?.title == "Your message did not go out")
        #expect(viewModel.failure?.isRetryable == true)
    }

    @Test("retryFailedMessages turns the send queue back on and clears the wedge")
    func retryFailedMessagesTurnsQueueBackOn() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)
        let viewModel = ChatViewModel(repository: repository)

        await viewModel.start()

        service.emit(sendQueueEvent: .failed(transactionID: "txn-1", reason: "offline", isRecoverable: true))
        await Eventually.isTrue { viewModel.isSendQueueWedged == true }
        #expect(viewModel.isSendQueueWedged == true)

        viewModel.retryFailedMessages()

        #expect(service.enableSendQueueCalls == [true])
        #expect(viewModel.isSendQueueWedged == false)
    }

    @Test("loadMore asks the repository to paginate backwards")
    func loadMoreAsksForOlderEvents() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)
        let viewModel = ChatViewModel(repository: repository)

        await viewModel.start()

        await viewModel.loadMore()

        #expect(service.paginateBackwardsCallCount == 1)
    }

    @Test("loadMore does nothing once pagination is already in flight")
    func loadMoreRespectsInFlightPagination() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)
        let viewModel = ChatViewModel(repository: repository)

        await viewModel.start()

        service.emit(paginationState: .paginating)
        await Eventually.isTrue { viewModel.isPaginating == true }

        #expect(viewModel.isPaginating == true)
        #expect(viewModel.canPaginate == false)

        await viewModel.loadMore()

        #expect(service.paginateBackwardsCallCount == 0)
    }

    @Test("loadMore does nothing once the start of the room has been reached")
    func loadMoreRespectsReachedStart() async {
        let service = MockTimelineService()
        let repository = TimelineRepository(service: service)
        let viewModel = ChatViewModel(repository: repository)

        await viewModel.start()

        service.emit(paginationState: .idle(hasReachedStart: true))
        await Eventually.isTrue { viewModel.canPaginate == false }

        #expect(viewModel.canPaginate == false)

        await viewModel.loadMore()

        #expect(service.paginateBackwardsCallCount == 0)
    }

    @Test("a pagination failure surfaces a user facing failure")
    func loadMoreFailureSurfaces() async {
        let service = MockTimelineService()
        service.paginateBackwardsResult = .failure(
            TimelineFailure.paginationFailed(Fixtures.sdkErrorInfo(kind: .network))
        )

        let repository = TimelineRepository(service: service)
        let viewModel = ChatViewModel(repository: repository)

        await viewModel.start()
        await viewModel.loadMore()

        #expect(viewModel.failure?.title == "Could not load older messages")
    }
}
