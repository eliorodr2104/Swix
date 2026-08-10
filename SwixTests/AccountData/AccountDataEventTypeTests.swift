//
//  AccountDataEventTypeTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("AccountDataEventType")
struct AccountDataEventTypeTests {

    @Test("the named constants carry their documented wire event type")
    func namedConstantsCarryWireEventType() {
        #expect(AccountDataEventType.direct.rawValue == "m.direct")
        #expect(AccountDataEventType.ignoredUserList.rawValue == "m.ignored_user_list")
        #expect(AccountDataEventType.fullyRead.rawValue == "m.fully_read")
        #expect(AccountDataEventType.tag.rawValue == "m.tag")
        #expect(AccountDataEventType.markedUnread.rawValue == "m.marked_unread")
    }

    @Test("a secret storage key namespaces its key id under the shared prefix")
    func secretStorageKeyNamespacesKeyID() {
        #expect(AccountDataEventType.secretStorageKey("abc123").rawValue == "m.secret_storage.key.abc123")
    }

    @Test("two event types with the same raw value are equal")
    func sameRawValueIsEqual() {
        #expect(AccountDataEventType.custom("m.direct") == AccountDataEventType.direct)
    }

    @Test("a custom event type carries whatever string it was given")
    func customEventTypeCarriesGivenString() {
        #expect(AccountDataEventType.custom("org.example.widget").rawValue == "org.example.widget")
    }
}
