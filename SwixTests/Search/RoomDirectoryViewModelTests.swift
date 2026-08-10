//
//  RoomDirectoryViewModelTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("RoomDirectoryViewModel")
struct RoomDirectoryViewModelTests {

    @Test("rapid query changes yield exactly one directory call, for the last query typed")
    func rapidQueryChangesYieldOneCall() async {
        let service = MockRoomDirectorySearchService()
        let repository = RoomDirectoryRepository(service: service)
        let viewModel = RoomDirectoryViewModel(repository: repository)

        viewModel.query = "m"
        viewModel.query = "ma"
        viewModel.query = "mat"
        viewModel.query = "matr"
        viewModel.query = "matrix"

        try? await Task.sleep(for: .milliseconds(400))

        #expect(service.searchCalls.map(\.filter) == ["matrix"])
    }

    @Test("stop cancels the pending debounce")
    func stopCancelsDebounce() async {
        let service = MockRoomDirectorySearchService()
        let repository = RoomDirectoryRepository(service: service)
        let viewModel = RoomDirectoryViewModel(repository: repository)

        viewModel.query = "matrix"
        viewModel.stop()

        try? await Task.sleep(for: .milliseconds(400))

        #expect(service.searchCalls.isEmpty)
    }
}
