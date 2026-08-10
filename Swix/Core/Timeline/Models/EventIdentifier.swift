//
//  EventIdentifier.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// How a timeline entry names the event it stands for.
///
/// A message the user just sent has no event id until the homeserver acknowledges it, so until
/// then it is only addressable by the transaction id the send queue gave it.
enum EventIdentifier: Equatable, Hashable {

    /// The event id the homeserver assigned, present once the event is a remote echo.
    case event(String)

    /// The send queue transaction id of a local echo that has not been acknowledged yet.
    case transaction(String)

    /// The underlying string, whichever of the two kinds this is.
    var value: String {
        switch self {
            case .event(let eventID): eventID
            case .transaction(let transactionID): transactionID
        }
    }

    /// The event id, or nil while the event is still a local echo.
    var eventID: String? {
        guard case .event(let eventID) = self else {
            return nil
        }

        return eventID
    }

    /// The transaction id, or nil once the event has been acknowledged by the homeserver.
    var transactionID: String? {
        guard case .transaction(let transactionID) = self else {
            return nil
        }

        return transactionID
    }

    /// Whether this event is still waiting for the homeserver to acknowledge it.
    var isLocalEcho: Bool {
        transactionID != nil
    }
}
