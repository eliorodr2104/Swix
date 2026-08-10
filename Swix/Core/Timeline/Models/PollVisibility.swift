//
//  PollVisibility.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Whether a poll shows its running tally while it is still open.
///
/// Named for what it does rather than mirroring the SDK's `PollKind`, both because "kind" says
/// nothing on its own and because a same named type would shadow the SDK's inside every file that
/// imports it.
enum PollVisibility: Equatable {

    /// Vote counts are visible to everyone as they come in.
    case disclosed

    /// Vote counts stay hidden until the poll is ended.
    case undisclosed
}
