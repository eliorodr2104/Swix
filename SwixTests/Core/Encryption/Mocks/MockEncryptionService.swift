//
//  MockEncryptionService.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

@testable import Swix


/// Records every call `EncryptionRepository` makes and lets a test push new states through the
/// four streams whenever it wants, rather than only at `start()` time.
final class MockEncryptionService: EncryptionServiceProtocol {

    var verificationStatus: DeviceVerificationStatus = .unknown

    var recoveryStatus: RecoveryStatus = .unknown

    var backupStatus: KeyBackupStatus = .unknown

    let verificationStatusStream: AsyncStream<DeviceVerificationStatus>

    let recoveryStatusStream: AsyncStream<RecoveryStatus>

    let backupStatusStream: AsyncStream<KeyBackupStatus>

    let recoveryProgressStream: AsyncStream<RecoveryProgress>

    let verificationStatusContinuation: AsyncStream<DeviceVerificationStatus>.Continuation

    let recoveryStatusContinuation: AsyncStream<RecoveryStatus>.Continuation

    let backupStatusContinuation: AsyncStream<KeyBackupStatus>.Continuation

    let recoveryProgressContinuation: AsyncStream<RecoveryProgress>.Continuation

    private(set) var startCallCount = 0

    private(set) var recoverCallCount = 0

    private(set) var lastRecoveryKey: String?

    private(set) var enableRecoveryCallCount = 0

    private(set) var lastEnableRecoveryArgs: (waitForBackupsToUpload: Bool, passphrase: String?)?

    private(set) var resetRecoveryKeyCallCount = 0

    private(set) var disableRecoveryCallCount = 0

    private(set) var backupExistsOnServerCallCount = 0

    private(set) var waitForBackupUploadSteadyStateCallCount = 0

    private(set) var waitForE2eeInitializationTasksCallCount = 0

    private(set) var shutdownCallCount = 0

    var startError: (any Error)?

    var recoverError: (any Error)?

    var enableRecoveryResult: Result<String, any Error> = .success("generated-recovery-key")

    var resetRecoveryKeyResult: Result<String, any Error> = .success("reset-recovery-key")

    var disableRecoveryError: (any Error)?

    var backupExistsOnServerResult: Result<Bool, any Error> = .success(false)

    var waitForBackupUploadSteadyStateError: (any Error)?

    init() {
        (verificationStatusStream, verificationStatusContinuation) = AsyncStream<DeviceVerificationStatus>.makeStream(bufferingPolicy: .unbounded)
        (recoveryStatusStream, recoveryStatusContinuation) = AsyncStream<RecoveryStatus>.makeStream(bufferingPolicy: .unbounded)
        (backupStatusStream, backupStatusContinuation) = AsyncStream<KeyBackupStatus>.makeStream(bufferingPolicy: .unbounded)
        (recoveryProgressStream, recoveryProgressContinuation) = AsyncStream<RecoveryProgress>.makeStream(bufferingPolicy: .unbounded)
    }

    func start() throws {
        startCallCount += 1

        if let startError {
            throw startError
        }
    }

    func recover(recoveryKey: String) async throws {
        recoverCallCount += 1
        lastRecoveryKey = recoveryKey

        if let recoverError {
            throw recoverError
        }
    }

    func enableRecovery(
        waitForBackupsToUpload: Bool,
        passphrase            : String?
    ) async throws -> String {

        enableRecoveryCallCount += 1
        lastEnableRecoveryArgs = (waitForBackupsToUpload, passphrase)

        return try enableRecoveryResult.get()
    }

    func resetRecoveryKey() async throws -> String {
        resetRecoveryKeyCallCount += 1

        return try resetRecoveryKeyResult.get()
    }

    func disableRecovery() async throws {
        disableRecoveryCallCount += 1

        if let disableRecoveryError {
            throw disableRecoveryError
        }
    }

    func backupExistsOnServer() async throws -> Bool {
        backupExistsOnServerCallCount += 1

        return try backupExistsOnServerResult.get()
    }

    func waitForBackupUploadSteadyState() async throws {
        waitForBackupUploadSteadyStateCallCount += 1

        if let waitForBackupUploadSteadyStateError {
            throw waitForBackupUploadSteadyStateError
        }
    }

    func waitForE2eeInitializationTasks() async {
        waitForE2eeInitializationTasksCallCount += 1
    }

    func shutdown() {
        shutdownCallCount += 1
    }
}
