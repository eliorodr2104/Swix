//
//  UserStatusInfo.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// A user set status (MSC4426 `m.status` profile field): a short emoji plus free text.
struct UserStatusInfo: Equatable {

    /// The emoji the user picked to represent the status.
    let emoji: String

    /// The free text that goes with the emoji.
    let text: String

    init(emoji: String, text: String) {
        self.emoji = emoji
        self.text = text
    }
}
