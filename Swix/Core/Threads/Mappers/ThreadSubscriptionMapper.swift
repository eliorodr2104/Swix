//
//  ThreadSubscriptionMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns the homeserver's answer about a thread subscription into the state a row can render.
enum ThreadSubscriptionMapper {

    /// Maps what `Room.fetchThreadSubscription` came back with.
    ///
    /// An absent subscription is a definite "not following", never a missing answer: the request
    /// succeeded and said there is nothing there, which is why this can never produce `.unknown`.
    static func makeState(from subscription: ThreadSubscription?) -> ThreadSubscriptionState {
        guard let subscription else {
            return .unsubscribed
        }

        return .subscribed(isAutomatic: subscription.automatic)
    }
}
