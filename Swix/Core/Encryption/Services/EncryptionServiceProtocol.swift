//
//  EncryptionServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Everything the account's end to end encryption exposes: whether this device is trusted, whether
/// recovery and key backup are on, and the operations that change them.
protocol EncryptionServiceProtocol {

    /// Trust state of this device right now, `.unknown` until `start()` has run.
    var verificationStatus: DeviceVerificationStatus { get }

    /// Recovery state of the account right now, `.unknown` until `start()` has run.
    var recoveryStatus: RecoveryStatus { get }

    /// Key backup state right now, `.unknown` until `start()` has run.
    var backupStatus: KeyBackupStatus { get }

    /// Every later trust state, starting with the one that was current when `start()` ran.
    var verificationStatusStream: AsyncStream<DeviceVerificationStatus> { get }

    /// Every later recovery state, starting with the one that was current when `start()` ran.
    var recoveryStatusStream: AsyncStream<RecoveryStatus> { get }

    /// Every later key backup state, starting with the one that was current when `start()` ran.
    var backupStatusStream: AsyncStream<KeyBackupStatus> { get }

    /// Progress of whichever long running recovery or backup operation is in flight, silent
    /// the rest of the time.
    var recoveryProgressStream: AsyncStream<RecoveryProgress> { get }

    /// Attaches to the live client and starts reporting states. Safe to call more than once.
    func start() throws

    /// Unlocks secret storage with a recovery key the user typed, restoring the key backup.
    func recover(recoveryKey: String) async throws

    /// Turns recovery on and hands back the freshly generated recovery key, which the SDK will
    /// never give out again.
    func enableRecovery(
        waitForBackupsToUpload: Bool,
        passphrase            : String?
    ) async throws -> String

    /// Replaces the recovery key of an account that already has recovery, returning the new one.
    func resetRecoveryKey() async throws -> String

    /// Removes recovery and the key backup from the homeserver.
    func disableRecovery() async throws

    /// Asks the homeserver whether a backup version exists, the only way to tell an absent backup
    /// from one this device simply cannot read.
    func backupExistsOnServer() async throws -> Bool

    /// Waits until every pending room key has been uploaded, reporting progress meanwhile.
    func waitForBackupUploadSteadyState() async throws

    /// Waits for the background encryption bootstrap the SDK runs right after a login.
    func waitForE2eeInitializationTasks() async

    /// Releases every listener this service owns. Called once, when the session ends.
    func shutdown()
}
