//
//  TimelineNotice.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// A timeline row that reports something about the room rather than something someone said.
///
/// Joins, leaves, topic and avatar changes, calls, redactions and events this build cannot even
/// parse all collapse into one already readable line: the timeline renders them as a small centered
/// note, and nothing downstream needs to know which of them it came from.
struct TimelineNotice: Identifiable, Equatable {

    /// The SDK's unique id for the row this notice replaced.
    let id: String

    /// The line to show, built in English by `TimelineNoticeMapper` and never empty.
    let text: String

    /// When it happened, absent for the handful of rows the SDK does not timestamp.
    let timestamp: Date?
}
