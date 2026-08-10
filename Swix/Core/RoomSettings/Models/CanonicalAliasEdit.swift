//
//  CanonicalAliasEdit.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// One request to change a room's canonical alias together with its alternates, since the SDK's
/// `updateCanonicalAlias` call always replaces both at once rather than editing either alone.
struct CanonicalAliasEdit: Equatable {

    /// The room's new canonical alias, or `nil` to clear it while keeping `alternates`.
    let alias: String?

    /// The full replacement list of alternate aliases; an empty array clears them all.
    let alternates: [String]
}
