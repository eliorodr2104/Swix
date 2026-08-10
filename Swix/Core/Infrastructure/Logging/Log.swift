//
//  Log.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import os


/// Namespace for every `os.Logger` the Core uses, one per feature area.
///
/// Grouping by category (rather than one shared logger) is what makes the Console app's
/// category filter useful when chasing a bug in, say, only the timeline or only sync.
enum Log {

    private static let subsystem = "hylo.Swix"

    /// Login, logout, session restore, soft logout and keychain persistence.
    static let session = Logger(subsystem: subsystem, category: "session")

    /// Password and OAuth authentication flows, homeserver discovery.
    static let auth = Logger(subsystem: subsystem, category: "auth")

    /// SyncService lifecycle and connectivity state.
    static let sync = Logger(subsystem: subsystem, category: "sync")

    /// Room list entries, filters and diff application.
    static let roomList = Logger(subsystem: subsystem, category: "roomList")

    /// Timeline diffs, sending, pagination and read receipts.
    static let timeline = Logger(subsystem: subsystem, category: "timeline")

    /// Session verification (SAS), recovery and key backup.
    static let encryption = Logger(subsystem: subsystem, category: "encryption")

    /// Element Call widget lifecycle and signaling.
    static let calls = Logger(subsystem: subsystem, category: "calls")

    /// Media upload, download and thumbnailing.
    static let media = Logger(subsystem: subsystem, category: "media")

    /// One-shot location sends and live location sharing.
    static let location = Logger(subsystem: subsystem, category: "location")

    /// Local message search, room directory search and user search.
    static let search = Logger(subsystem: subsystem, category: "search")

    /// Notification settings, pushers and notification decoding.
    static let notifications = Logger(subsystem: subsystem, category: "notifications")

    /// Global and room scoped account data, read, written and observed.
    static let accountData = Logger(subsystem: subsystem, category: "accountData")

    /// Room metadata edits: name, topic, avatar, join rule, visibility and encryption.
    static let roomSettings = Logger(subsystem: subsystem, category: "roomSettings")

    /// Cross-cutting Core plumbing: collections, storage, configuration, bridging.
    static let infrastructure = Logger(subsystem: subsystem, category: "infrastructure")
}
