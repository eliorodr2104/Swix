//
//  SyncStateMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns the two SDK enums the sync engine pushes out into their Core domain equivalents.
enum SyncStateMapper {

    /// Maps `SyncServiceState`. The SDK's `.error` becomes `.failed`: Core never repeats the SDK's
    /// own vocabulary verbatim, so a future SDK release renaming or adding a case fails to compile
    /// here instead of silently mislabeling the state.
    static func makeSyncState(from state: SyncServiceState) -> SyncState {
        switch state {
            case .idle: .idle
            case .running: .running
            case .terminated: .terminated
            case .error: .failed
            case .offline: .offline
        }
    }

    /// Maps `RoomListServiceSyncIndicator`, the SDK's already debounced show/hide signal.
    static func makeSyncIndicatorState(
        from indicator: RoomListServiceSyncIndicator
    ) -> SyncIndicatorState {
        switch indicator {
            case .show: .visible
            case .hide: .hidden
        }
    }
}
