//
//  SDKErrorInfo.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK

/// Normalized shape of any error the Matrix SDK can throw.
///
/// This is the single place allowed to switch on raw SDK error enums; every feature's
/// `SwixFailure` gets built from an `SDKErrorInfo` instead of pattern matching the SDK itself.
struct SDKErrorInfo {

    let kind: SDKErrorKind
    let message: String
    let details: String?

    init(
        kind   : SDKErrorKind,
        message: String,
        details: String?
    ) {
        self.kind    = kind
        self.message = message
        self.details = details
    }

    /// Classifies any error the SDK can throw. Errors from types this file does not recognize
    /// fall back to `.unknown` with a best effort description, so this never fails to construct.
    init(_ error: any Error) {
        switch error {
            case let clientError as ClientError:
                self = Self.info(from: clientError)

            case let roomListError as RoomListError:
                self = Self.info(from: roomListError)

            case let roomError as RoomError:
                self = Self.info(from: roomError)

            case let buildError as ClientBuildError:
                self = Self.info(from: buildError)

            case let recoveryError as RecoveryError:
                self = Self.info(from: recoveryError)

            case let oauthError as OAuthError:
                self = Self.info(from: oauthError)

            default:
                self = SDKErrorInfo(
                    kind   : .unknown,
                    message: String(reflecting: error),
                    details: nil
                )
        }
    }

    private static func info(from error: ClientError) -> SDKErrorInfo {
        switch error {
            case .Generic(let msg, let details):
                SDKErrorInfo(
                    kind   : .unknown,
                    message: msg,
                    details: details
                )

            case .MatrixApi(let kind, _, let msg, let details):
                SDKErrorInfo(
                    kind   : classify(kind),
                    message: msg,
                    details: details
                )

            case .ContentScanner(let reason, let info):
                SDKErrorInfo(
                    kind   : classify(reason),
                    message: info,
                    details: nil
                )
        }
    }

    private static func info(from error: RoomListError) -> SDKErrorInfo {
        switch error {
            case .SlidingSync(let error):
                SDKErrorInfo(
                    kind   : .unknown,
                    message: error,
                    details: nil
                )

            case .UnknownList(let listName):
                SDKErrorInfo(
                    kind   : .unknown,
                    message: "Unknown room list: \(listName)",
                    details: nil
                )

            case .InputCannotBeApplied:
                SDKErrorInfo(
                    kind   : .unknown,
                    message: "The requested change cannot be applied to the room list",
                    details: nil
                )

            case .RoomNotFound(let roomName):
                SDKErrorInfo(
                    kind   : .notFound,
                    message: "Room not found: \(roomName)",
                    details: nil
                )

            case .InvalidRoomId(let error):
                SDKErrorInfo(
                    kind   : .unknown,
                    message: error,
                    details: nil
                )

            case .EventCache(let error):
                SDKErrorInfo(
                    kind   : .unknown,
                    message: error,
                    details: nil
                )

            case .IncorrectRoomMembership(let expected, let actual):
                SDKErrorInfo(
                    kind   : .forbidden,
                    message: "Expected membership \(expected), got \(actual)",
                    details: nil
                )
        }
    }

    private static func info(from error: RoomError) -> SDKErrorInfo {
        switch error {
            case .InvalidAttachmentData(let message),
                 .InvalidAttachmentMimeType(let message),
                 .InvalidMediaInfo(let message),
                 .TimelineUnavailable(let message),
                 .InvalidThumbnailData(let message),
                 .InvalidRepliedToEventId(let message),
                 .FailedSendingAttachment(let message):
                return SDKErrorInfo(kind: .unknown, message: message, details: nil)
        }
    }

    private static func info(from error: ClientBuildError) -> SDKErrorInfo {
        switch error {
            case .ServerUnreachable(let message), .WellKnownLookupFailed(let message):
                SDKErrorInfo(kind: .network, message: message, details: nil)

            case .InvalidServerName(let message),
                 .WellKnownDeserializationError(let message),
                 .SlidingSync(let message),
                 .SlidingSyncVersion(let message),
                 .Sdk(let message),
                 .EventCache(let message),
                 .InvalidRawKey(let message),
                 .Generic(let message):
                SDKErrorInfo(kind: .unknown, message: message, details: nil)
        }
    }

    private static func info(from error: RecoveryError) -> SDKErrorInfo {
        switch error {
            case .BackupExistsOnServer:
                SDKErrorInfo(
                    kind   : .unknown,
                    message: "A backup already exists on the homeserver",
                    details: nil
                )

            case .Client(let source):
                Self.info(from: source)

            case .SecretStorage(let errorMessage), .Import(let errorMessage):
                SDKErrorInfo(
                    kind   : .unknown,
                    message: errorMessage,
                    details: nil
                )
        }
    }

    private static func info(from error: OAuthError) -> SDKErrorInfo {
        switch error {
            case .NotSupported(let message),
                 .MetadataInvalid(let message),
                 .CallbackUrlInvalid(let message),
                 .Cancelled(let message),
                 .Generic(let message):
                return SDKErrorInfo(kind: .unknown, message: message, details: nil)
        }
    }

    private static func classify(_ kind: ErrorKind) -> SDKErrorKind {
        switch kind {
            case .connectionFailed, .connectionTimeout: .network
            case .unknownToken    , .missingToken     : .authenticationExpired

            case .forbidden , .guestAccessForbidden, .unauthorized  , .userDeactivated,
                 .userLocked, .userSuspended       , .cannotLeaveServerNoticeRoom,
                 .exclusive, .captchaNeeded        , .captchaInvalid, .threepidDenied,
                 .threepidAuthFailed, .unableToAuthorizeJoin, .unableToGrantJoin: .forbidden

            case .notFound                             : .notFound
            case .limitExceeded, .resourceLimitExceeded: .rateLimited
            default                                    : .unknown
        }
    }

    private static func classify(_ reason: ErrorReason) -> SDKErrorKind {
        switch reason {
            case .mMissingToken, .mUnknownToken          : .authenticationExpired
            case .mNotFound                              : .notFound
            case .mcsMediaNotClean, .mcsMimeTypeForbidden: .forbidden
            case .mcsMediaRequestFailed                  : .network
            default                                      : .unknown
        }
    }
}
