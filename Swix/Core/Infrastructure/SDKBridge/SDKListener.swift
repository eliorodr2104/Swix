//
//  SDKListener.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


// This file is the only nonisolated corner of the app. UniFFI invokes every callback synchronously
// from a tokio worker thread through a C vtable, and declares the listener protocols as Sendable,
// so a MainActor isolated type is structurally unable to conform to them. Everything the SDK pushes
// is funnelled here into AsyncStreams that the rest of the Core consumes back on MainActor.

/// Owns the continuation of an `AsyncStream` and terminates it when the listener is released.
///
/// SE-0406 stopped finishing a stream when its continuation is deinited, so without this wrapper the
/// consumer task would stay suspended forever once the SDK drops the listener.
private nonisolated final class StreamContinuationWrapper<Value: Sendable>: Sendable {

    private let continuation: AsyncStream<Value>.Continuation

    init(continuation: AsyncStream<Value>.Continuation) {
        self.continuation = continuation
    }

    /// Hands one value to the stream without ever blocking the caller.
    func yield(_ value: Value) {
        continuation.yield(value)
    }

    deinit {
        continuation.finish()
    }
}

/// The single adapter between the SDK callback protocols and Swift concurrency.
///
/// One instance backs one subscription: pass it to the SDK, retain the returned `TaskHandle`, and
/// iterate the paired stream wherever the values are needed.
nonisolated final class SDKListener<Value: Sendable>: Sendable {

    private let wrapper: StreamContinuationWrapper<Value>

    init(continuation: AsyncStream<Value>.Continuation) {
        self.wrapper = StreamContinuationWrapper(continuation: continuation)
    }

    /// Publishes one callback payload to the stream.
    func emit(_ value: Value) {
        wrapper.yield(value)
    }
}

/// Builds an unbounded stream together with the listener that feeds it.
///
/// Buffering is unbounded on purpose: SDK updates are incremental diffs, so dropping one under
/// back pressure would silently desynchronise the mirrored collection. The value type is a
/// parameter because a generic function cannot be specialised explicitly at the call site.
nonisolated func makeSDKStream<Value: Sendable>(of valueType: Value.Type = Value.self) -> (stream: AsyncStream<Value>, listener: SDKListener<Value>) {

    let (stream, continuation) = AsyncStream<Value>.makeStream(of: Value.self, bufferingPolicy: .unbounded)

    return (stream, SDKListener(continuation: continuation))
}

/// Client wide events flattened from the multi method `ClientDelegate`.
extension SDKListener: ClientDelegate where Value == SDKClientEvent {

    nonisolated func didReceiveAuthError(isSoftLogout: Bool) {
        emit(.authError(isSoftLogout: isSoftLogout))
    }

    nonisolated func onBackgroundTaskErrorReport(
        taskName: String,
        error   : BackgroundTaskFailureReason
    ) {
        emit(.backgroundTaskError(taskName: taskName, reason: error))
    }
}

/// Lifecycle of the sync service, from `SyncService.state(listener:)`.
extension SDKListener: SyncServiceStateObserver where Value == SyncServiceState {

    nonisolated func onUpdate(state: SyncServiceState) {
        emit(state)
    }
}

/// Room list service lifecycle, from `RoomListService.state(listener:)`.
extension SDKListener: RoomListServiceStateListener where Value == RoomListServiceState {

    nonisolated func onUpdate(state: RoomListServiceState) {
        emit(state)
    }
}

/// Debounced connectivity indicator, from `RoomListService.syncIndicator(...)`.
extension SDKListener: RoomListServiceSyncIndicatorListener where Value == RoomListServiceSyncIndicator {

    nonisolated func onUpdate(syncIndicator: RoomListServiceSyncIndicator) {
        emit(syncIndicator)
    }
}

/// Room list diffs, from `RoomList.entriesWithDynamicAdapters(pageSize:listener:)`.
extension SDKListener: RoomListEntriesListener where Value == [RoomListEntriesUpdate] {

    nonisolated func onUpdate(roomEntriesUpdate: [RoomListEntriesUpdate]) {
        emit(roomEntriesUpdate)
    }
}

/// First load progress of the room list, from `RoomList.loadingState(listener:)`.
extension SDKListener: RoomListLoadingStateListener where Value == RoomListLoadingState {

    nonisolated func onUpdate(state: RoomListLoadingState) {
        emit(state)
    }
}

/// Per room metadata updates, from `Room.subscribeToRoomInfoUpdates(listener:)`.
extension SDKListener: RoomInfoListener where Value == RoomInfo {

    nonisolated func call(roomInfo: RoomInfo) {
        emit(roomInfo)
    }
}

/// Timeline diffs, from `Timeline.addListener(listener:)`.
extension SDKListener: TimelineListener where Value == [TimelineDiff] {

    nonisolated func onUpdate(diff: [TimelineDiff]) {
        emit(diff)
    }
}

/// Back pagination progress, from `Timeline.subscribeToBackPaginationStatus(listener:)`.
extension SDKListener: PaginationStatusListener where Value == PaginationStatus {

    nonisolated func onUpdate(status: PaginationStatus) {
        emit(status)
    }
}

/// Send queue updates of a single room, from `Room.subscribeToSendQueueUpdates(listener:)`.
extension SDKListener: SendQueueListener where Value == RoomSendQueueUpdate {

    nonisolated func onUpdate(update: RoomSendQueueUpdate) {
        emit(update)
    }
}

/// Send queue updates of every room, from `Client.subscribeToSendQueueUpdates(listener:)`.
extension SDKListener: SendQueueRoomUpdateListener where Value == SDKSendQueueRoomUpdate {

    nonisolated func onUpdate(
        roomId: String,
        update: RoomSendQueueUpdate
    ) {
        emit(SDKSendQueueRoomUpdate(roomID: roomId, update: update))
    }
}

/// Wedged send queues, from `Client.subscribeToSendQueueStatus(listener:)`.
extension SDKListener: SendQueueRoomErrorListener where Value == SDKSendQueueRoomError {

    nonisolated func onError(
        roomId: String,
        error : ClientError
    ) {
        emit(SDKSendQueueRoomError(roomID: roomId, error: error))
    }
}

/// Cross signing state of this device, from `Encryption.verificationStateListener(listener:)`.
extension SDKListener: VerificationStateListener where Value == VerificationState {

    nonisolated func onUpdate(status: VerificationState) {
        emit(status)
    }
}

/// Key backup state, from `Encryption.backupStateListener(listener:)`.
extension SDKListener: BackupStateListener where Value == BackupState {

    nonisolated func onUpdate(status: BackupState) {
        emit(status)
    }
}

/// Recovery state, from `Encryption.recoveryStateListener(listener:)`.
extension SDKListener: RecoveryStateListener where Value == RecoveryState {

    nonisolated func onUpdate(status: RecoveryState) {
        emit(status)
    }
}

/// Backup upload progress, from `Encryption.waitForBackupUploadSteadyState(progressListener:)`.
extension SDKListener: BackupSteadyStateListener where Value == BackupUploadState {

    nonisolated func onUpdate(status: BackupUploadState) {
        emit(status)
    }
}

/// Recovery enablement progress, from `Encryption.enableRecovery(...)`.
extension SDKListener: EnableRecoveryProgressListener where Value == EnableRecoveryProgress {

    nonisolated func onUpdate(status: EnableRecoveryProgress) {
        emit(status)
    }
}

/// Interactive verification steps flattened from the multi method delegate.
extension SDKListener: SessionVerificationControllerDelegate where Value == SDKVerificationEvent {

    nonisolated func didReceiveVerificationRequest(details: SessionVerificationRequestDetails) {
        emit(.receivedRequest(details: details))
    }

    nonisolated func didAcceptVerificationRequest() {
        emit(.acceptedRequest)
    }

    nonisolated func didStartSasVerification() {
        emit(.startedSas)
    }

    nonisolated func didReceiveVerificationData(data: SessionVerificationData) {
        emit(.receivedData(data: data))
    }

    nonisolated func didFail() {
        emit(.failed)
    }

    nonisolated func didCancel() {
        emit(.cancelled)
    }

    nonisolated func didFinish() {
        emit(.finished)
    }
}

/// Thread list diffs, from `ThreadListService.subscribeToItemsUpdates(listener:)`.
extension SDKListener: ThreadListEntriesListener where Value == [ThreadListUpdate] {

    nonisolated func onUpdate(diff: [ThreadListUpdate]) {
        emit(diff)
    }
}

/// Thread list pagination, from `ThreadListService.subscribeToPaginationStateUpdates(listener:)`.
extension SDKListener: ThreadListPaginationStateListener where Value == ThreadListPaginationState {

    nonisolated func onUpdate(state: ThreadListPaginationState) {
        emit(state)
    }
}

/// Local search results, from `SearchService.subscribeToResults(listener:)`.
extension SDKListener: SearchServiceResultsListener where Value == [SearchServiceResultsUpdate] {

    nonisolated func onUpdate(updates: [SearchServiceResultsUpdate]) {
        emit(updates)
    }
}

/// Local search pagination, from `SearchService.subscribeToPaginationStateUpdates(listener:)`.
extension SDKListener: SearchServicePaginationStateListener where Value == SearchServicePaginationState {

    nonisolated func onUpdate(paginationState: SearchServicePaginationState) {
        emit(paginationState)
    }
}

/// Public room directory results, from `RoomDirectorySearch.results(listener:)`.
extension SDKListener: RoomDirectorySearchEntriesListener where Value == [RoomDirectorySearchEntryUpdate] {

    nonisolated func onUpdate(roomEntriesUpdate: [RoomDirectorySearchEntryUpdate]) {
        emit(roomEntriesUpdate)
    }
}

/// Notifications produced by sync, from `Client.registerNotificationHandler(listener:)`.
extension SDKListener: SyncNotificationListener where Value == SDKSyncNotification {

    nonisolated func onNotification(
        notification: MatrixRustSDK.NotificationItem,
        roomId      : String
    ) {
        emit(SDKSyncNotification(notification: notification, roomID: roomId))
    }
}

/// Push rule changes, from `NotificationSettings.setDelegate(delegate:)`.
extension SDKListener: NotificationSettingsDelegate where Value == SDKNotificationSettingsEvent {

    nonisolated func settingsDidChange() {
        emit(.settingsDidChange)
    }
}

/// The current user's profile, from `Client.subscribeToOwnProfile(listener:)`.
extension SDKListener: ProfileListener where Value == UserProfile {

    nonisolated func onUpdate(profile: UserProfile) {
        emit(profile)
    }
}

/// The ignored user list, from `Client.subscribeToIgnoredUsers(listener:)`.
extension SDKListener: IgnoredUsersListener where Value == [String] {

    nonisolated func call(ignoredUserIds: [String]) {
        emit(ignoredUserIds)
    }
}

/// Who is typing in a room, from `Room.subscribeToTypingNotifications(listener:)`.
extension SDKListener: TypingNotificationsListener where Value == SDKTypingNotification {

    nonisolated func call(typingUserIds: [String]) {
        emit(SDKTypingNotification(userIDs: typingUserIds))
    }
}

/// Media transfer progress normalised to a zero to one fraction.
extension SDKListener: ProgressWatcher where Value == Double {

    nonisolated func transmissionProgress(progress: TransmissionProgress) {
        guard progress.total > 0 else {
            emit(0)
            return
        }

        emit(Double(progress.current) / Double(progress.total))
    }
}

/// Inline media preview policy, from `Client.subscribeToMediaPreviewConfig(listener:)`.
extension SDKListener: MediaPreviewConfigListener where Value == MediaPreviewConfig? {

    nonisolated func onChange(mediaPreviewConfig: MediaPreviewConfig?) {
        emit(mediaPreviewConfig)
    }
}

/// Live location shares of a room, from `LiveLocationsObserver.subscribe(listener:)`.
extension SDKListener: LiveLocationsListener where Value == [LiveLocationShareUpdate] {

    nonisolated func onUpdate(updates: [LiveLocationShareUpdate]) {
        emit(updates)
    }
}

/// The current user's beacons, from `Client.subscribeToOwnBeaconInfoUpdates(listener:)`.
extension SDKListener: BeaconInfoListener where Value == BeaconInfoUpdate {

    nonisolated func onUpdate(update: BeaconInfoUpdate) {
        emit(update)
    }
}

/// Global account data, from `Client.observeAccountDataEvent(eventType:listener:)`.
extension SDKListener: AccountDataListener where Value == AccountDataEvent {

    nonisolated func onChange(event: AccountDataEvent) {
        emit(event)
    }
}

/// Room scoped account data, from `Client.observeRoomAccountDataEvent(roomId:eventType:listener:)`.
extension SDKListener: RoomAccountDataListener where Value == SDKRoomAccountDataEvent {

    nonisolated func onChange(
        event : RoomAccountDataEvent,
        roomId: String
    ) {
        emit(SDKRoomAccountDataEvent(event: event, roomID: roomId))
    }
}

/// Call declines, from `Room.subscribeToCallDeclineEvents(rtcNotificationEventId:listener:)`.
extension SDKListener: CallDeclineListener where Value == String {

    nonisolated func call(declinerUserId: String) {
        emit(declinerUserId)
    }
}
