//
//  ThreadSubscriptionState.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Whether the account follows a thread, and whether it chose to.
///
/// The homeserver only ever answers "there is a subscription" or "there is none" (MSC4306), so the
/// third case is ours alone: a thread nobody has asked about yet is neither of the two, and a row
/// that rendered a toggle from a guess would flip under the user the moment the real answer landed.
enum ThreadSubscriptionState: Equatable {

    /// Nobody has asked the homeserver about this thread yet.
    case unknown

    /// The account is not following the thread.
    case unsubscribed

    /// The account follows the thread. `isAutomatic` is true when the SDK subscribed on its own,
    /// after a mention for instance, rather than because the user asked for it.
    case subscribed(isAutomatic: Bool)

    /// Whether the account follows the thread right now. An unanswered question counts as not
    /// following, which is what keeps a toggle off until the truth arrives.
    var isSubscribed: Bool {
        switch self {
            case .subscribed: true
            case .unknown, .unsubscribed: false
        }
    }

    /// Whether the homeserver has actually answered, which is what a toggle has to know before it
    /// can let the user touch it.
    var isKnown: Bool {
        self != .unknown
    }
}
