//
//  NotificationSyncServiceProviding.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Hands back the SDK sync engine driving this session, when there is one.
///
/// SERVICE LAYER ONLY: this exposes a raw `SyncService`, which repositories and view models must
/// never see. It exists so the notification client can share the running sync loop instead of
/// starting a second one, and it is deliberately a separate protocol so a Notification Service
/// Extension, where no sync loop exists, can simply not provide it.
protocol NotificationSyncServiceProviding {

    /// The sync service currently running in this process, nil before sync has started.
    func activeSyncService() -> SyncService?
}
