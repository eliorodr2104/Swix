//
//  PollAnswerEntry.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// One option of a poll, with its tally already resolved.
///
/// The SDK reports votes as a map from answer id to the users who picked it, which is the wrong way
/// round for drawing a bar per answer, so the count and the "I voted for this" flag are folded into
/// the answer itself while mapping.
struct PollAnswerEntry: Identifiable, Equatable {

    /// The answer id the homeserver assigned, which is what a vote refers to.
    let id: String

    /// The text of the option as the poll's author wrote it.
    let text: String

    /// How many people picked this option. Zero for an undisclosed poll that has not ended yet,
    /// because the homeserver withholds the tally until then.
    let voteCount: Int

    /// Whether the signed in account picked this option.
    let isOwnVote: Bool
}
