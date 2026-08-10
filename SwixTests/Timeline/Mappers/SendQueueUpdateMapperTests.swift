//
//  SendQueueUpdateMapperTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
import MatrixRustSDK
@testable import Swix


@Suite("SendQueueUpdateMapper")
struct SendQueueUpdateMapperTests {

    @Test("newLocalEvent maps to queued")
    func newLocalEventMapsToQueued() {
        let event = SendQueueUpdateMapper.makeEvent(from: .newLocalEvent(transactionId: "txn-1"))

        #expect(event == .queued(transactionID: "txn-1"))
    }

    @Test("cancelledLocalEvent maps to cancelled")
    func cancelledLocalEventMapsToCancelled() {
        let event = SendQueueUpdateMapper.makeEvent(from: .cancelledLocalEvent(transactionId: "txn-1"))

        #expect(event == .cancelled(transactionID: "txn-1"))
    }

    @Test("replacedLocalEvent maps to replaced")
    func replacedLocalEventMapsToReplaced() {
        let event = SendQueueUpdateMapper.makeEvent(from: .replacedLocalEvent(transactionId: "txn-1"))

        #expect(event == .replaced(transactionID: "txn-1"))
    }

    @Test("retryEvent maps to retrying")
    func retryEventMapsToRetrying() {
        let event = SendQueueUpdateMapper.makeEvent(from: .retryEvent(transactionId: "txn-1"))

        #expect(event == .retrying(transactionID: "txn-1"))
    }

    @Test("sentEvent maps to sent, carrying the assigned event id")
    func sentEventMapsToSent() {
        let event = SendQueueUpdateMapper.makeEvent(
            from: .sentEvent(transactionId: "txn-1", eventId: "$event1")
        )

        #expect(event == .sent(transactionID: "txn-1", eventID: "$event1"))
    }

    @Test("sendError maps to failed, carrying the reason and recoverability")
    func sendErrorMapsToFailed() {
        let event = SendQueueUpdateMapper.makeEvent(
            from: .sendError(
                transactionId: "txn-1",
                error        : .crossVerificationRequired,
                isRecoverable: true
            )
        )

        #expect(
            event ==
            .failed(
                transactionID: "txn-1",
                reason       : SendQueueUpdateMapper.makeReason(from: .crossVerificationRequired),
                isRecoverable: true
            )
        )
    }

    @Test("mediaUpload maps to uploadProgress with a zero to one fraction")
    func mediaUploadMapsToUploadProgress() {
        let event = SendQueueUpdateMapper.makeEvent(
            from: .mediaUpload(
                relatedTo: "media-1",
                file     : nil,
                index    : 0,
                progress : AbstractProgress(current: 25, total: 100)
            )
        )

        #expect(event == .uploadProgress(relatedTo: "media-1", fraction: 0.25))
    }

    @Test("mediaUpload reports zero progress rather than dividing by a zero total")
    func mediaUploadWithZeroTotalReportsZero() {
        let event = SendQueueUpdateMapper.makeEvent(
            from: .mediaUpload(
                relatedTo: "media-1",
                file     : nil,
                index    : 0,
                progress : AbstractProgress(current: 0, total: 0)
            )
        )

        #expect(event == .uploadProgress(relatedTo: "media-1", fraction: 0))
    }

    @Test("makeReason explains every wedge error in a sentence a user can read")
    func makeReasonCoversEveryCase() {
        #expect(
            SendQueueUpdateMapper.makeReason(from: .insecureDevices(userDeviceMap: [:])) ==
            "Some devices in this room are not verified."
        )

        #expect(
            SendQueueUpdateMapper.makeReason(from: .identityViolations(users: [])) ==
            "Someone in this room changed their identity."
        )

        #expect(
            SendQueueUpdateMapper.makeReason(from: .crossVerificationRequired) ==
            "This device has to be verified before it can send messages."
        )

        #expect(
            SendQueueUpdateMapper.makeReason(from: .missingMediaContent) ==
            "The attachment is no longer on this device."
        )

        #expect(
            SendQueueUpdateMapper.makeReason(from: .invalidMimeType(mimeType: "application/x-evil")) ==
            "Files of type application/x-evil cannot be sent."
        )

        #expect(
            SendQueueUpdateMapper.makeReason(from: .genericApiError(msg: "Something broke")) ==
            "Something broke"
        )
    }
}
