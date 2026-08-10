//
//  RoomMetadataDraft.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// A batch of room metadata edits a settings screen collects before sending them to the
/// homeserver.
///
/// Every field is optional because a draft usually touches only one or two settings at a time;
/// `RoomSettingsRepository.apply(_:)` sends one request per non nil field and stops at the first
/// failure, so the fields the user never touched are never sent at all.
struct RoomMetadataDraft: Equatable {

    /// The room's new name, or `nil` to leave it untouched.
    var name: String?

    /// The room's new topic, or `nil` to leave it untouched.
    var topic: String?

    /// The room's new join rule, or `nil` to leave it untouched.
    var joinRule: JoinRuleSetting?

    /// The room's new history visibility, or `nil` to leave it untouched.
    var historyVisibility: HistoryVisibilitySetting?

    /// The room's new directory visibility, or `nil` to leave it untouched.
    var visibility: RoomVisibilitySetting?

    /// The room's new canonical alias and alternates, or `nil` to leave both untouched.
    var canonicalAlias: CanonicalAliasEdit?

    init(
        name             : String? = nil,
        topic            : String? = nil,
        joinRule         : JoinRuleSetting? = nil,
        historyVisibility: HistoryVisibilitySetting? = nil,
        visibility       : RoomVisibilitySetting? = nil,
        canonicalAlias   : CanonicalAliasEdit? = nil
    ) {
        self.name              = name
        self.topic             = topic
        self.joinRule          = joinRule
        self.historyVisibility = historyVisibility
        self.visibility        = visibility
        self.canonicalAlias    = canonicalAlias
    }

    /// Whether every field was left untouched, which means there is nothing worth sending.
    var isEmpty: Bool {
        name == nil
            && topic == nil
            && joinRule == nil
            && historyVisibility == nil
            && visibility == nil
            && canonicalAlias == nil
    }
}
