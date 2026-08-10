//
//  ChatListViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("ChatListViewModel")
struct ChatListViewModelTests {

    /// Short enough that a test waiting past it does not feel slow, long enough that two
    /// synchronous keystrokes reliably land inside the same debounce window.
    private static let debounce: Duration = .milliseconds(5)

    @Test("pinned and chats mirror the repository's own partition")
    func sectionsMirrorRepository() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)
        let viewModel = ChatListViewModel(
            repository    : repository,
            actionsService: MockRoomActionsService()
        )

        await viewModel.start()

        let pinned = Fixtures.roomSummary(id: "!pinned:example.org", isFavourite: true)
        let ordinary = Fixtures.roomSummary(id: "!ordinary:example.org")

        service.emit(diffs: [.reset([pinned, ordinary])])
        await Eventually.isTrue { !viewModel.pinned.isEmpty }

        #expect(viewModel.pinned.map(\.id) == ["!pinned:example.org"])
        #expect(viewModel.chats.map(\.id) == ["!ordinary:example.org"])
    }

    @Test("isLoading and isEmpty follow the repository's load state")
    func loadingAndEmptyFollowLoadState() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)
        let viewModel = ChatListViewModel(
            repository    : repository,
            actionsService: MockRoomActionsService()
        )

        await viewModel.start()

        #expect(viewModel.isLoading == true)
        #expect(viewModel.isEmpty == false)

        service.emit(loadState: .loaded(totalRoomCount: 0))
        await Eventually.isTrue { viewModel.isLoading == false }

        #expect(viewModel.isLoading == false)
        #expect(viewModel.isEmpty == true)
    }

    @Test("isSyncing is false with no sync repository attached")
    func isSyncingFalseWithoutSyncRepository() {
        let viewModel = ChatListViewModel(
            repository    : RoomListRepository(entriesService: MockRoomListEntriesService()),
            actionsService: MockRoomActionsService()
        )

        #expect(viewModel.isSyncing == false)
    }

    @Test("isSyncing mirrors the attached sync repository's indicator")
    func isSyncingMirrorsSyncRepository() async {
        let coordinator = MockSyncCoordinator()
        let syncRepository = SyncRepository(coordinator: coordinator)
        let viewModel = ChatListViewModel(
            repository    : RoomListRepository(entriesService: MockRoomListEntriesService()),
            actionsService: MockRoomActionsService(),
            syncRepository: syncRepository
        )

        await syncRepository.start()

        coordinator.emit(indicator: .visible)
        await Eventually.isTrue { viewModel.isSyncing == true }

        #expect(viewModel.isSyncing == true)
    }

    @Test("typing a search query applies it as a filter once the debounce settles")
    func searchQueryAppliesFilterAfterDebounce() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)
        let viewModel = ChatListViewModel(
            repository    : repository,
            actionsService: MockRoomActionsService(),
            searchDebounce: Self.debounce
        )

        viewModel.searchQuery = "matrix"

        await Eventually.isTrue { service.appliedFilters == [.search("matrix")] }

        #expect(service.appliedFilters == [.search("matrix")])
    }

    @Test("clearing the search query goes back to the all filter")
    func clearingSearchQueryRestoresAllFilter() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)
        let viewModel = ChatListViewModel(
            repository    : repository,
            actionsService: MockRoomActionsService(),
            searchDebounce: Self.debounce
        )

        viewModel.searchQuery = "matrix"
        await Eventually.isTrue { service.appliedFilters == [.search("matrix")] }

        viewModel.searchQuery = ""
        await Eventually.isTrue { service.appliedFilters.last == .all }

        #expect(service.appliedFilters.last == .all)
    }

    @Test("a second keystroke inside the debounce window cancels the first one's filter")
    func rapidTypingOnlyAppliesTheLastQuery() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)
        let viewModel = ChatListViewModel(
            repository    : repository,
            actionsService: MockRoomActionsService(),
            searchDebounce: Self.debounce
        )

        viewModel.searchQuery = "m"
        viewModel.searchQuery = "ma"
        viewModel.searchQuery = "mat"

        await Eventually.isTrue { !service.appliedFilters.isEmpty }

        #expect(service.appliedFilters == [.search("mat")])
    }

    @Test("setting the same query twice does not restart the debounce")
    func settingTheSameQueryTwiceIsANoOp() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)
        let viewModel = ChatListViewModel(
            repository    : repository,
            actionsService: MockRoomActionsService(),
            searchDebounce: Self.debounce
        )

        viewModel.searchQuery = "matrix"
        viewModel.searchQuery = "matrix"

        await Eventually.isTrue { !service.appliedFilters.isEmpty }

        #expect(service.appliedFilters == [.search("matrix")])
    }

    @Test("toggleFavourite pins a room that was not pinned")
    func toggleFavouritePinsAnUnpinnedRoom() async {
        let service = MockRoomListEntriesService()
        let actionsService = MockRoomActionsService()
        let repository = RoomListRepository(entriesService: service)
        let viewModel = ChatListViewModel(
            repository    : repository,
            actionsService: actionsService
        )

        await viewModel.start()

        let room = Fixtures.roomSummary(id: "!room:example.org", isFavourite: false)
        service.emit(diffs: [.reset([room])])
        await Eventually.isTrue { !viewModel.chats.isEmpty }

        await viewModel.toggleFavourite(roomID: "!room:example.org")

        #expect(actionsService.favouriteCalls.count == 1)
        #expect(actionsService.favouriteCalls.first?.isFavourite == true)
        #expect(actionsService.favouriteCalls.first?.roomID == "!room:example.org")
        #expect(viewModel.failure == nil)
    }

    @Test("toggleFavourite unpins a room that was already pinned")
    func toggleFavouriteUnpinsAPinnedRoom() async {
        let service = MockRoomListEntriesService()
        let actionsService = MockRoomActionsService()
        let repository = RoomListRepository(entriesService: service)
        let viewModel = ChatListViewModel(
            repository    : repository,
            actionsService: actionsService
        )

        await viewModel.start()

        let room = Fixtures.roomSummary(id: "!room:example.org", isFavourite: true)
        service.emit(diffs: [.reset([room])])
        await Eventually.isTrue { !viewModel.pinned.isEmpty }

        await viewModel.toggleFavourite(roomID: "!room:example.org")

        #expect(actionsService.favouriteCalls.first?.isFavourite == false)
    }

    @Test("toggleFavourite on an unknown room id does nothing")
    func toggleFavouriteOnUnknownRoomDoesNothing() async {
        let actionsService = MockRoomActionsService()
        let viewModel = ChatListViewModel(
            repository    : RoomListRepository(entriesService: MockRoomListEntriesService()),
            actionsService: actionsService
        )

        await viewModel.toggleFavourite(roomID: "!missing:example.org")

        #expect(actionsService.favouriteCalls.isEmpty)
    }

    @Test("a failed toggleFavourite surfaces a user facing failure")
    func toggleFavouriteFailureSurfaces() async {
        let service = MockRoomListEntriesService()
        let actionsService = MockRoomActionsService()
        actionsService.errorToThrow = RoomListFailure.actionFailed(Fixtures.sdkErrorInfo(kind: .network))

        let repository = RoomListRepository(entriesService: service)
        let viewModel = ChatListViewModel(
            repository    : repository,
            actionsService: actionsService
        )

        await viewModel.start()

        let room = Fixtures.roomSummary(id: "!room:example.org")
        service.emit(diffs: [.reset([room])])
        await Eventually.isTrue { !viewModel.chats.isEmpty }

        await viewModel.toggleFavourite(roomID: "!room:example.org")

        #expect(viewModel.failure?.title == "Something went wrong")
        #expect(viewModel.failure?.isRetryable == true)
    }
}
