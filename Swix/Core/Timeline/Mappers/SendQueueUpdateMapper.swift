//
//  SendQueueUpdateMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns what the room's send queue reports into a domain event, and a wedged queue error into a
/// sentence the user can act on.
enum SendQueueUpdateMapper {

    /// Maps one queue update.
    static func makeEvent(from update: RoomSendQueueUpdate) -> SendQueueEvent {
        switch update {
            case .newLocalEvent(let transactionID):
                return .queued(transactionID: transactionID)

            case .cancelledLocalEvent(let transactionID):
                return .cancelled(transactionID: transactionID)

            case .replacedLocalEvent(let transactionID):
                return .replaced(transactionID: transactionID)

            case .sendError(let transactionID, let error, let isRecoverable):
                return .failed(
                    transactionID: transactionID,
                    reason       : makeReason(from: error),
                    isRecoverable: isRecoverable
                )

            case .retryEvent(let transactionID):
                return .retrying(transactionID: transactionID)

            case .sentEvent(let transactionID, let eventID):
                return .sent(
                    transactionID: transactionID,
                    eventID      : eventID
                )

            case .mediaUpload(let relatedTo, _, _, let progress):
                return .uploadProgress(
                    relatedTo: relatedTo,
                    fraction : makeFraction(from: progress)
                )
        }
    }

    /// Explains why the queue got stuck on a message.
    ///
    /// This is shared with `TimelineEntryMapper`, because the very same error also reaches us as
    /// the failed send state of an event that is already in the timeline.
    static func makeReason(from error: QueueWedgeError) -> String {
        switch error {
            case .insecureDevices:
                "Some devices in this room are not verified."

            case .identityViolations:
                "Someone in this room changed their identity."

            case .crossVerificationRequired:
                "This device has to be verified before it can send messages."

            case .missingMediaContent:
                "The attachment is no longer on this device."

            case .invalidMimeType(let mimeType):
                "Files of type \(mimeType) cannot be sent."

            case .genericApiError(let msg):
                msg
        }
    }

    /// A total of zero means the SDK has not sized the upload yet, which reads as no progress
    /// rather than as a division by zero.
    private static func makeFraction(from progress: AbstractProgress) -> Double {
        guard progress.total > 0 else {
            return 0
        }

        return Double(progress.current) / Double(progress.total)
    }
}
