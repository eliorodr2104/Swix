//
//  UserSearchViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("UserSearchViewModel")
struct UserSearchViewModelTests {

    @Test("rapid query changes yield exactly one directory call, for the last query typed")
    func rapidQueryChangesYieldOneCall() async {
        let service = MockUserSearchService()
        let repository = UserSearchRepository(service: service)
        let viewModel = UserSearchViewModel(repository: repository)

        viewModel.query = "a"
        viewModel.query = "al"
        viewModel.query = "ali"
        viewModel.query = "alic"
        viewModel.query = "alice"

        try? await Task.sleep(for: .milliseconds(400))

        #expect(service.searchCalls.map(\.term) == ["alice"])
    }

    @Test("stop cancels the pending debounce and clears the field")
    func stopCancelsDebounce() async {
        let service = MockUserSearchService()
        let repository = UserSearchRepository(service: service)
        let viewModel = UserSearchViewModel(repository: repository)

        viewModel.query = "alice"
        viewModel.stop()

        try? await Task.sleep(for: .milliseconds(400))

        #expect(service.searchCalls.isEmpty)
        #expect(viewModel.query.isEmpty)
    }
}
