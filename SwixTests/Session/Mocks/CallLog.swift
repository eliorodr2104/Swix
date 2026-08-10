//
//  CallLog.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//


/// One ordered record shared by two or more mocks, so a test can assert that a call on one of
/// them happened before a call on another even though each mock only sees its own calls.
final class CallLog {

    private(set) var entries: [String] = []

    init() {}

    /// Appends one entry, tagged with whichever mock recorded it.
    func record(_ entry: String) {
        entries.append(entry)
    }
}
