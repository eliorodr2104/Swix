//
//  SDKErrorInfoTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import Testing
@testable import Swix


/// Covers how every SDK error enum `SDKErrorInfo` knows about gets classified into an
/// `SDKErrorKind`, plus the fallback for an error type it does not recognize.
@Suite("SDKErrorInfo classification")
struct SDKErrorInfoTests {

    // MARK: ClientError

    @Test("ClientError.Generic keeps its message and details, classified as unknown")
    func clientErrorGeneric() {
        let info = SDKErrorInfo(ClientError.Generic(msg: "boom", details: "extra"))

        #expect(info.kind == .unknown)
        #expect(info.message == "boom")
        #expect(info.details == "extra")
    }

    @Test(
        "ClientError.MatrixApi classifies its ErrorKind",
        arguments: [
            (ErrorKind.connectionFailed, SDKErrorKind.network),
            (ErrorKind.connectionTimeout, SDKErrorKind.network),
            (ErrorKind.unknownToken(softLogout: false), SDKErrorKind.authenticationExpired),
            (ErrorKind.missingToken, SDKErrorKind.authenticationExpired),
            (ErrorKind.forbidden, SDKErrorKind.forbidden),
            (ErrorKind.notFound, SDKErrorKind.notFound),
            (ErrorKind.limitExceeded(retryAfterMs: nil), SDKErrorKind.rateLimited),
            (ErrorKind.badJson, SDKErrorKind.unknown)
        ]
    )
    func clientErrorMatrixApiClassification(
        sdkKind     : ErrorKind,
        expectedKind: SDKErrorKind
    ) {
        let info = SDKErrorInfo(
            ClientError.MatrixApi(kind: sdkKind, code: "500", msg: "failure", details: nil)
        )

        #expect(info.kind == expectedKind)
        #expect(info.message == "failure")
    }

    @Test(
        "ClientError.ContentScanner classifies its ErrorReason",
        arguments: [
            (ErrorReason.mMissingToken, SDKErrorKind.authenticationExpired),
            (ErrorReason.mUnknownToken, SDKErrorKind.authenticationExpired),
            (ErrorReason.mNotFound, SDKErrorKind.notFound),
            (ErrorReason.mcsMediaNotClean, SDKErrorKind.forbidden),
            (ErrorReason.mcsMimeTypeForbidden, SDKErrorKind.forbidden),
            (ErrorReason.mcsMediaRequestFailed, SDKErrorKind.network),
            (ErrorReason.mcsMalformedJson, SDKErrorKind.unknown)
        ]
    )
    func clientErrorContentScannerClassification(
        sdkReason   : ErrorReason,
        expectedKind: SDKErrorKind
    ) {
        let info = SDKErrorInfo(
            ClientError.ContentScanner(reason: sdkReason, info: "scan failed")
        )

        #expect(info.kind == expectedKind)
        #expect(info.message == "scan failed")
    }

    // MARK: RoomListError

    @Test("RoomListError.RoomNotFound classifies as notFound")
    func roomListErrorRoomNotFound() {
        let info = SDKErrorInfo(RoomListError.RoomNotFound(roomName: "!room:example.org"))

        #expect(info.kind == .notFound)
        #expect(info.message.contains("!room:example.org"))
    }

    @Test("RoomListError.IncorrectRoomMembership classifies as forbidden")
    func roomListErrorIncorrectRoomMembership() {
        let info = SDKErrorInfo(
            RoomListError.IncorrectRoomMembership(expected: [.joined], actual: .left)
        )

        #expect(info.kind == .forbidden)
    }

    @Test("RoomListError.InputCannotBeApplied classifies as unknown with a fixed message")
    func roomListErrorInputCannotBeApplied() {
        let info = SDKErrorInfo(RoomListError.InputCannotBeApplied)

        #expect(info.kind == .unknown)
        #expect(info.message == "The requested change cannot be applied to the room list")
    }

    // MARK: RoomError

    @Test("Every RoomError case classifies as unknown and keeps its message")
    func roomErrorAlwaysUnknown() {
        let info = SDKErrorInfo(RoomError.InvalidAttachmentData(message: "bad data"))

        #expect(info.kind == .unknown)
        #expect(info.message == "bad data")
    }

    // MARK: ClientBuildError

    @Test(
        "ClientBuildError classifies network failures distinctly from the rest",
        arguments: [
            (ClientBuildError.ServerUnreachable(message: "offline"), SDKErrorKind.network),
            (ClientBuildError.WellKnownLookupFailed(message: "offline"), SDKErrorKind.network),
            (ClientBuildError.InvalidServerName(message: "bad name"), SDKErrorKind.unknown),
            (ClientBuildError.Sdk(message: "internal"), SDKErrorKind.unknown)
        ]
    )
    func clientBuildErrorClassification(
        sdkError    : ClientBuildError,
        expectedKind: SDKErrorKind
    ) {
        let info = SDKErrorInfo(sdkError)

        #expect(info.kind == expectedKind)
    }

    // MARK: RecoveryError

    @Test("RecoveryError.BackupExistsOnServer classifies as unknown with a fixed message")
    func recoveryErrorBackupExists() {
        let info = SDKErrorInfo(RecoveryError.BackupExistsOnServer)

        #expect(info.kind == .unknown)
        #expect(info.message == "A backup already exists on the homeserver")
    }

    @Test("RecoveryError.Client unwraps the underlying ClientError instead of going opaque")
    func recoveryErrorClientUnwraps() {
        let info = SDKErrorInfo(
            RecoveryError.Client(source: .MatrixApi(kind: .forbidden, code: "403", msg: "no", details: nil))
        )

        #expect(info.kind == .forbidden)
        #expect(info.message == "no")
    }

    @Test("RecoveryError.SecretStorage keeps its message, classified as unknown")
    func recoveryErrorSecretStorage() {
        let info = SDKErrorInfo(RecoveryError.SecretStorage(errorMessage: "wrong key"))

        #expect(info.kind == .unknown)
        #expect(info.message == "wrong key")
    }

    // MARK: OAuthError

    @Test("Every OAuthError case classifies as unknown and keeps its message")
    func oauthErrorAlwaysUnknown() {
        let info = SDKErrorInfo(OAuthError.Cancelled(message: "user cancelled"))

        #expect(info.kind == .unknown)
        #expect(info.message == "user cancelled")
    }

    // MARK: Fallback

    @Test("An error type this file does not recognize falls back to .unknown with a description")
    func unrecognizedErrorFallsBackToUnknown() {
        struct SomeOtherError: Error {}

        let info = SDKErrorInfo(SomeOtherError())

        #expect(info.kind == .unknown)
        #expect(!info.message.isEmpty)
        #expect(info.details == nil)
    }
}
