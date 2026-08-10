//
//  RoomDirectoryRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("RoomDirectoryRepository")
struct RoomDirectoryRepositoryTests {

    @Test("an empty query browses the whole directory with a nil filter")
    func emptyQueryBrowsesWholeDirectory() async {
        let service = MockRoomDirectorySearchService()
        let repository = RoomDirectoryRepository(service: service)

        await repository.search(query: "")

        #expect(service.searchCalls.count == 1)
        #expect(service.searchCalls.first?.filter == nil)
    }

    @Test("a non empty query is trimmed and passed as the filter")
    func nonEmptyQueryIsTrimmedAndPassed() async {
        let service = MockRoomDirectorySearchService()
        let repository = RoomDirectoryRepository(service: service)

        await repository.search(query: "  matrix  ")

        #expect(service.searchCalls.first?.filter == "matrix")
    }

    @Test("repeating the same filter twice in a row does nothing the second time")
    func repeatingFilterIsANoOp() async {
        let service = MockRoomDirectorySearchService()
        let repository = RoomDirectoryRepository(service: service)

        await repository.search(query: "matrix")
        await repository.search(query: "matrix")

        #expect(service.searchCalls.count == 1)
    }

    @Test("but the very first empty query still runs, even though it repeats no filter")
    func firstEmptyQueryStillRuns() async {
        let service = MockRoomDirectorySearchService()
        let repository = RoomDirectoryRepository(service: service)

        await repository.search(query: "")

        #expect(service.searchCalls.count == 1)
    }

    @Test("after a page lands, loadState reflects whether the directory has more pages")
    func loadStateReflectsMorePages() async {
        let service = MockRoomDirectorySearchService()
        let repository = RoomDirectoryRepository(service: service)

        service.isAtLastPageValue = false

        await repository.search(query: "matrix")

        #expect(repository.loadState == .loaded(hasMoreResults: true))
    }

    @Test("loadMore paginates only while there is more to load")
    func loadMorePaginatesWhileThereIsMore() async {
        let service = MockRoomDirectorySearchService()
        let repository = RoomDirectoryRepository(service: service)

        service.isAtLastPageValue = true

        await repository.search(query: "matrix")
        await repository.loadMore()

        #expect(service.loadNextPageCallCount == 0)
    }

    @Test("result diffs from the service are applied to rooms")
    func resultDiffsAreApplied() async {
        let service = MockRoomDirectorySearchService()
        let repository = RoomDirectoryRepository(service: service)

        await repository.search(query: "matrix")

        service.diffContinuation.yield([.reset([Self.makeRoom(id: "!room:example.org")])])

        await Eventually.isTrue { !repository.rooms.isEmpty }

        #expect(repository.rooms.map(\.id) == ["!room:example.org"])
    }

    @Test("shutdown releases the service")
    func shutdownReleasesService() {
        let service = MockRoomDirectorySearchService()
        let repository = RoomDirectoryRepository(service: service)

        repository.shutdown()

        #expect(service.shutdownCallCount == 1)
    }

    private static func makeRoom(id: String) -> DirectoryRoom {
        DirectoryRoom(
            id             : id,
            name           : "Room",
            topic          : nil,
            alias          : nil,
            avatarURL      : nil,
            memberCount    : 1,
            joinRule       : .open,
            isWorldReadable: false
        )
    }
}
