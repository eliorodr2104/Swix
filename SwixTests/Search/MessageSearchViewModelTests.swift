//
//  MessageSearchViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("MessageSearchViewModel")
struct MessageSearchViewModelTests {

    @Test("rapid query changes yield exactly one service call, for the last query typed")
    func rapidQueryChangesYieldOneCall() async {
        let service = MockMessageSearchService()
        let repository = MessageSearchRepository(service: service)
        let viewModel = MessageSearchViewModel(repository: repository)

        viewModel.query = "h"
        viewModel.query = "he"
        viewModel.query = "hel"
        viewModel.query = "hell"
        viewModel.query = "hello"

        // The debounce window is 250ms; waiting comfortably past it without ever letting it fire
        // early is what proves every keystroke restarted the same timer instead of scheduling five.
        try? await Task.sleep(for: .milliseconds(400))

        #expect(service.queries == ["hello"])
    }

    @Test("clearing the field after typing cancels the pending search")
    func clearingFieldCancelsPendingSearch() async {
        let service = MockMessageSearchService()
        let repository = MessageSearchRepository(service: service)
        let viewModel = MessageSearchViewModel(repository: repository)

        viewModel.query = "hello"
        viewModel.query = ""

        try? await Task.sleep(for: .milliseconds(400))

        #expect(service.queries.isEmpty)
    }

    @Test("stop cancels the debounce and clears the query")
    func stopCancelsDebounce() async {
        let service = MockMessageSearchService()
        let repository = MessageSearchRepository(service: service)
        let viewModel = MessageSearchViewModel(repository: repository)

        viewModel.query = "hello"
        viewModel.stop()

        try? await Task.sleep(for: .milliseconds(400))

        #expect(service.queries.isEmpty)
        #expect(viewModel.query.isEmpty)
    }
}
