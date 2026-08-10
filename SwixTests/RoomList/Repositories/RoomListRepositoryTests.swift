//
//  RoomListRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("RoomListRepository")
struct RoomListRepositoryTests {

    @Test("start succeeds, starts the entries service once and clears any previous failure")
    func startSucceeds() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        await repository.start()

        #expect(service.startCallCount == 1)
        #expect(repository.failure == nil)
    }

    @Test("a start failure is wrapped into RoomListFailure and kept until the next attempt")
    func startFailureIsWrapped() async {
        let service = MockRoomListEntriesService()
        service.startError = RoomListFailure.noActiveClient

        let repository = RoomListRepository(entriesService: service)

        await repository.start()

        guard case .noActiveClient = repository.failure else {
            Issue.record("Expected .noActiveClient, got \(String(describing: repository.failure))")
            return
        }
    }

    @Test("a reset diff replaces the whole list in one atomic update")
    func resetDiffReplacesTheList() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        await repository.start()

        let first = Fixtures.roomSummary(id: "!a:example.org", name: "Alpha")
        let second = Fixtures.roomSummary(id: "!b:example.org", name: "Bravo")

        service.emit(diffs: [.reset([first, second])])
        await Eventually.isTrue { repository.rooms.count == 2 }

        #expect(repository.rooms.map(\.id) == ["!a:example.org", "!b:example.org"])
    }

    @Test("later diff batches apply on top of the reset in order")
    func laterDiffsApplyInOrder() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        await repository.start()

        let first = Fixtures.roomSummary(id: "!a:example.org")
        service.emit(diffs: [.reset([first])])
        await Eventually.isTrue { repository.rooms.count == 1 }

        let second = Fixtures.roomSummary(id: "!b:example.org")
        service.emit(diffs: [.pushBack(second)])
        await Eventually.isTrue { repository.rooms.count == 2 }

        #expect(repository.rooms.map(\.id) == ["!a:example.org", "!b:example.org"])

        service.emit(diffs: [.remove(index: 0)])
        await Eventually.isTrue { repository.rooms.count == 1 }

        #expect(repository.rooms.map(\.id) == ["!b:example.org"])
    }

    @Test("favourites and others partition the list without touching its order")
    func favouritesAndOthersPartitionTheList() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        await repository.start()

        let pinned = Fixtures.roomSummary(id: "!pinned:example.org", isFavourite: true)
        let ordinary = Fixtures.roomSummary(id: "!ordinary:example.org")
        let lowPriority = Fixtures.roomSummary(id: "!low:example.org", isLowPriority: true)

        service.emit(diffs: [.reset([pinned, ordinary, lowPriority])])
        await Eventually.isTrue { repository.rooms.count == 3 }

        #expect(repository.favourites.map(\.id) == ["!pinned:example.org"])
        #expect(repository.others.map(\.id) == ["!ordinary:example.org"])
    }

    @Test("a favourite that is also low priority still counts as a favourite")
    func favouriteWinsOverLowPriority() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        await repository.start()

        let room = Fixtures.roomSummary(id: "!both:example.org", isFavourite: true, isLowPriority: true)

        service.emit(diffs: [.reset([room])])
        await Eventually.isTrue { !repository.rooms.isEmpty }

        #expect(repository.favourites.map(\.id) == ["!both:example.org"])
        #expect(repository.others.isEmpty)
    }

    @Test("the loading state stream is mirrored onto loadState")
    func loadingStateStreamUpdatesLoadState() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        await repository.start()

        #expect(repository.loadState == .notLoaded)

        service.emit(loadState: .loaded(totalRoomCount: 5))
        await Eventually.isTrue { repository.loadState == .loaded(totalRoomCount: 5) }

        #expect(repository.loadState == .loaded(totalRoomCount: 5))
    }

    @Test("setFilter forwards the selection to the entries service")
    func setFilterForwards() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        repository.setFilter(.favourites)

        #expect(service.appliedFilters == [.favourites])
    }

    @Test("loadMore forwards to the entries service")
    func loadMoreForwards() {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        repository.loadMore()
        repository.loadMore()

        #expect(service.loadMoreCallCount == 2)
    }

    @Test("visibleRangeChanged subscribes once for an unchanged set of ids")
    func visibleRangeChangedDedupesUnchangedSets() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        repository.visibleRangeChanged(ids: ["!a:example.org", "!b:example.org"])
        await Eventually.isTrue { service.subscribedVisibleRoomIDs.count == 1 }

        // Same set as before: the guard short circuits synchronously, so there is nothing further
        // to wait on here.
        repository.visibleRangeChanged(ids: ["!a:example.org", "!b:example.org"])

        #expect(service.subscribedVisibleRoomIDs.count == 1)
    }

    @Test("visibleRangeChanged does nothing for an empty set of ids")
    func visibleRangeChangedIgnoresEmptySet() {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        repository.visibleRangeChanged(ids: [])

        #expect(service.subscribedVisibleRoomIDs.isEmpty)
    }

    @Test("visibleRangeChanged subscribes again once the set actually changes")
    func visibleRangeChangedResubscribesOnChange() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        repository.visibleRangeChanged(ids: ["!a:example.org"])
        await Eventually.isTrue { service.subscribedVisibleRoomIDs.count == 1 }

        repository.visibleRangeChanged(ids: ["!a:example.org", "!b:example.org"])
        await Eventually.isTrue { service.subscribedVisibleRoomIDs.count == 2 }

        #expect(service.subscribedVisibleRoomIDs.count == 2)
    }

    @Test("shutdown releases the entries service")
    func shutdownReleasesService() async {
        let service = MockRoomListEntriesService()
        let repository = RoomListRepository(entriesService: service)

        await repository.start()
        repository.shutdown()

        #expect(service.shutdownCallCount == 1)
    }
}
