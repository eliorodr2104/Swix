//
//  PresenceServiceTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("PresenceService")
struct PresenceServiceTests {

    @Test("every operation fails with noActiveClient before a session produces a live client")
    func operationsFailWithoutActiveClient() async {
        let clientService = MockInertClientService()
        let service = PresenceService(clientService: clientService)

        await #expect(throws: UsersFailure.self) {
            try await service.setPresence(.online, immediate: false)
        }

        await #expect(throws: UsersFailure.self) {
            try await service.setUserStatus(UserStatusInfo(emoji: "🎉", text: "Celebrating"))
        }

        await #expect(throws: UsersFailure.self) {
            try await service.clearUserStatus()
        }

        await #expect(throws: UsersFailure.self) {
            _ = try await service.isUserStatusSupported()
        }
    }
}
