//
//  UserSearchRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("UserSearchRepository")
struct UserSearchRepositoryTests {

    @Test("a new term is forwarded to the directory and the answer lands as loaded")
    func newTermIsSearched() async {
        let service = MockUserSearchService()

        service.stubbedUsers = [Self.makeUser(userID: "@alice:example.org")]

        let repository = UserSearchRepository(service: service)

        await repository.search(query: "alice")

        #expect(service.searchCalls.map(\.term) == ["alice"])
        #expect(repository.users.map(\.userID) == ["@alice:example.org"])
        #expect(repository.loadState == .loaded(hasMoreResults: false))
    }

    @Test("repeating the term already loaded does nothing")
    func repeatingTermIsANoOp() async {
        let service = MockUserSearchService()
        let repository = UserSearchRepository(service: service)

        await repository.search(query: "alice")
        await repository.search(query: "alice")

        #expect(service.searchCalls.count == 1)
    }

    @Test("a slower answer to an older term never overwrites a newer one")
    func staleAnswerNeverOverwritesNewerResult() async {
        let service = MockUserSearchService()
        let repository = UserSearchRepository(service: service)

        let (releaseSignal, releaseContinuation) = AsyncStream<Void>.makeStream()
        let staleUser = Self.makeUser(userID: "@stale:example.org")
        let freshUser = Self.makeUser(userID: "@fresh:example.org")

        service.searchHandler = { term, _ in
            if term == "old" {
                for await _ in releaseSignal { break }

                return [staleUser]
            }

            return [freshUser]
        }

        // "old" starts first but is held back; "new" is asked for and answers immediately.
        let oldSearch = Task { await repository.search(query: "old") }

        // Give the first request a chance to actually enter the service before starting the second.
        try? await Task.sleep(for: .milliseconds(20))

        await repository.search(query: "new")

        #expect(repository.users.map(\.userID) == ["@fresh:example.org"])

        releaseContinuation.finish()

        _ = await oldSearch.value

        #expect(repository.users.map(\.userID) == ["@fresh:example.org"])
    }

    @Test("clear drops the term, the results, and makes any in-flight answer irrelevant")
    func clearMakesInFlightAnswerIrrelevant() async {
        let service = MockUserSearchService()
        let repository = UserSearchRepository(service: service)

        let (releaseSignal, releaseContinuation) = AsyncStream<Void>.makeStream()
        let lateUser = Self.makeUser(userID: "@late:example.org")

        service.searchHandler = { _, _ in
            for await _ in releaseSignal { break }

            return [lateUser]
        }

        let search = Task { await repository.search(query: "alice") }

        try? await Task.sleep(for: .milliseconds(20))

        repository.clear()
        releaseContinuation.finish()

        _ = await search.value

        #expect(repository.users.isEmpty)
        #expect(repository.loadState == .idle)
    }

    @Test("a directory failure is recorded and the load state settles")
    func directoryFailureIsRecorded() async {
        let service = MockUserSearchService()

        service.failureToThrow = SearchFailure.userSearchFailed(Fixtures.sdkErrorInfo())

        let repository = UserSearchRepository(service: service)

        await repository.search(query: "alice")

        #expect(repository.failure != nil)
        #expect(repository.loadState == .loaded(hasMoreResults: false))
    }

    private static func makeUser(userID: String) -> FoundUser {
        FoundUser(userID: userID, displayName: nil, avatarURL: nil)
    }
}
