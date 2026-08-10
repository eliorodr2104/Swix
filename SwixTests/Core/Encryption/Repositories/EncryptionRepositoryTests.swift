//
//  EncryptionRepositoryTests.swift
//  SwixTests
//
//  Created by Eliomar on 09/08/2026.
//

import Testing
@testable import Swix


@Suite("EncryptionRepository")
struct EncryptionRepositoryTests {

    // MARK: start()

    @Test("start() reads the service's current states synchronously")
    func startReadsCurrentStates() {
        let service = MockEncryptionService()
        service.verificationStatus = .verified
        service.recoveryStatus     = .enabled
        service.backupStatus       = .enabled

        let repository = EncryptionRepository(service: service)

        repository.start()

        #expect(repository.verificationStatus == .verified)
        #expect(repository.recoveryStatus == .enabled)
        #expect(repository.backupStatus == .enabled)
        #expect(repository.failure == nil)
        #expect(service.startCallCount == 1)
    }

    @Test("A second start() call is a no-op while already observing")
    func secondStartIsNoOp() {
        let service = MockEncryptionService()
        let repository = EncryptionRepository(service: service)

        repository.start()
        repository.start()

        #expect(service.startCallCount == 1)
    }

    @Test("A failing start() records the failure and leaves observing unattempted")
    func startFailureRecordsFailure() {
        let service = MockEncryptionService()
        service.startError = EncryptionFailure.noActiveClient

        let repository = EncryptionRepository(service: service)

        repository.start()

        #expect(repository.failure != nil)
        #expect(repository.verificationStatus == .unknown)
    }

    @Test("start() can be retried after a failure, since isObserving never flipped")
    func startCanBeRetriedAfterFailure() {
        let service = MockEncryptionService()
        service.startError = EncryptionFailure.noActiveClient

        let repository = EncryptionRepository(service: service)

        repository.start()
        repository.start()

        #expect(service.startCallCount == 2)
    }

    @Test("start() forwards every later value from the four state streams")
    func startForwardsLaterStreamValues() async {
        let service = MockEncryptionService()
        let repository = EncryptionRepository(service: service)

        repository.start()

        service.verificationStatusContinuation.yield(.verified)
        service.recoveryStatusContinuation.yield(.enabled)
        service.backupStatusContinuation.yield(.enabled)
        service.recoveryProgressContinuation.yield(.creatingBackup)

        await Eventually.isTrue { repository.verificationStatus == .verified }
        await Eventually.isTrue { repository.recoveryStatus == .enabled }
        await Eventually.isTrue { repository.backupStatus == .enabled }
        await Eventually.isTrue { repository.recoveryProgress == .creatingBackup }

        #expect(repository.verificationStatus == .verified)
        #expect(repository.recoveryStatus == .enabled)
        #expect(repository.backupStatus == .enabled)
        #expect(repository.recoveryProgress == .creatingBackup)
    }

    @Test("start() awaits the SDK's e2ee initialization tasks and re-reads the states afterward")
    func startAwaitsInitializationTasks() async {
        let service = MockEncryptionService()
        let repository = EncryptionRepository(service: service)

        repository.start()

        await Eventually.isTrue { service.waitForE2eeInitializationTasksCallCount == 1 }

        #expect(service.waitForE2eeInitializationTasksCallCount == 1)
    }

    // MARK: recover(withKey:)

    @Test("recover(withKey:) succeeds, clears the failure and re-reads the states")
    func recoverSucceeds() async {
        let service = MockEncryptionService()
        let repository = EncryptionRepository(service: service)
        repository.start()

        service.verificationStatus = .verified

        let didRecover = await repository.recover(withKey: "recovery-key")

        #expect(didRecover)
        #expect(service.lastRecoveryKey == "recovery-key")
        #expect(repository.verificationStatus == .verified)
        #expect(repository.failure == nil)
    }

    @Test("recover(withKey:) surfaces an invalid key as a recorded failure")
    func recoverFailureIsRecorded() async {
        let service = MockEncryptionService()
        service.recoverError = EncryptionFailure.invalidRecoveryKey(Fixtures.sdkErrorInfo())

        let repository = EncryptionRepository(service: service)

        let didRecover = await repository.recover(withKey: "wrong-key")

        #expect(!didRecover)

        guard case .invalidRecoveryKey = repository.failure else {
            Issue.record("Expected .invalidRecoveryKey, got \(String(describing: repository.failure))")
            return
        }
    }

    // MARK: generateRecoveryKey(passphrase:)

    @Test("generateRecoveryKey resets an existing key rather than enabling a second one")
    func generateRecoveryKeyResetsWhenEnabled() async {
        let service = MockEncryptionService()
        service.recoveryStatus = .enabled

        let repository = EncryptionRepository(service: service)
        repository.start()

        let key = await repository.generateRecoveryKey()

        #expect(key == "reset-recovery-key")
        #expect(service.resetRecoveryKeyCallCount == 1)
        #expect(service.enableRecoveryCallCount == 0)
    }

    @Test("generateRecoveryKey resets when recovery is merely incomplete, too")
    func generateRecoveryKeyResetsWhenIncomplete() async {
        let service = MockEncryptionService()
        service.recoveryStatus = .incomplete

        let repository = EncryptionRepository(service: service)
        repository.start()

        _ = await repository.generateRecoveryKey()

        #expect(service.resetRecoveryKeyCallCount == 1)
        #expect(service.enableRecoveryCallCount == 0)
    }

    @Test("generateRecoveryKey enables a fresh key when there was none")
    func generateRecoveryKeyEnablesWhenDisabled() async {
        let service = MockEncryptionService()
        service.recoveryStatus = .disabled

        let repository = EncryptionRepository(service: service)
        repository.start()

        let key = await repository.generateRecoveryKey(passphrase: "s3cret")

        #expect(key == "generated-recovery-key")
        #expect(service.enableRecoveryCallCount == 1)
        #expect(service.resetRecoveryKeyCallCount == 0)
        #expect(service.lastEnableRecoveryArgs?.passphrase == "s3cret")
    }

    // MARK: enableRecovery(waitForBackupsToUpload:passphrase:)

    @Test("enableRecovery reports its progress as starting and clears it once done")
    func enableRecoveryClearsProgressWhenDone() async {
        let service = MockEncryptionService()
        let repository = EncryptionRepository(service: service)

        let key = await repository.enableRecovery(waitForBackupsToUpload: true, passphrase: nil)

        #expect(key == "generated-recovery-key")
        #expect(service.lastEnableRecoveryArgs?.waitForBackupsToUpload == true)
        #expect(repository.recoveryProgress == nil)
        #expect(repository.failure == nil)
    }

    @Test("enableRecovery records the failure and still clears the transient progress")
    func enableRecoveryFailureClearsProgress() async {
        let service = MockEncryptionService()
        service.enableRecoveryResult = .failure(EncryptionFailure.recoveryFailed(Fixtures.sdkErrorInfo()))

        let repository = EncryptionRepository(service: service)

        let key = await repository.enableRecovery()

        #expect(key == nil)
        #expect(repository.recoveryProgress == nil)

        guard case .recoveryFailed = repository.failure else {
            Issue.record("Expected .recoveryFailed, got \(String(describing: repository.failure))")
            return
        }
    }

    // MARK: resetRecoveryKey()

    @Test("resetRecoveryKey returns the new key and re-reads the states")
    func resetRecoveryKeySucceeds() async {
        let service = MockEncryptionService()
        let repository = EncryptionRepository(service: service)

        let key = await repository.resetRecoveryKey()

        #expect(key == "reset-recovery-key")
        #expect(repository.failure == nil)
    }

    @Test("resetRecoveryKey records a failure when the SDK refuses")
    func resetRecoveryKeyFailure() async {
        let service = MockEncryptionService()
        service.resetRecoveryKeyResult = .failure(EncryptionFailure.sdk(Fixtures.sdkErrorInfo()))

        let repository = EncryptionRepository(service: service)

        let key = await repository.resetRecoveryKey()

        #expect(key == nil)
        #expect(repository.failure != nil)
    }

    // MARK: disableRecovery()

    @Test("disableRecovery clears the backup existence flag and re-reads the states")
    func disableRecoverySucceeds() async {
        let service = MockEncryptionService()
        let repository = EncryptionRepository(service: service)

        await repository.disableRecovery()

        #expect(repository.hasBackupOnServer == false)
        #expect(service.disableRecoveryCallCount == 1)
        #expect(repository.failure == nil)
    }

    @Test("disableRecovery records a failure and leaves the backup flag untouched")
    func disableRecoveryFailure() async {
        let service = MockEncryptionService()
        service.disableRecoveryError = EncryptionFailure.backupFailed(Fixtures.sdkErrorInfo())

        let repository = EncryptionRepository(service: service)

        await repository.disableRecovery()

        #expect(repository.hasBackupOnServer == nil)

        guard case .backupFailed = repository.failure else {
            Issue.record("Expected .backupFailed, got \(String(describing: repository.failure))")
            return
        }
    }

    // MARK: refreshBackupExistence()

    @Test("refreshBackupExistence publishes whatever the service answers")
    func refreshBackupExistenceSucceeds() async {
        let service = MockEncryptionService()
        service.backupExistsOnServerResult = .success(true)

        let repository = EncryptionRepository(service: service)

        await repository.refreshBackupExistence()

        #expect(repository.hasBackupOnServer == true)
    }

    @Test("refreshBackupExistence records a failure and leaves the flag at its previous value")
    func refreshBackupExistenceFailure() async {
        let service = MockEncryptionService()
        service.backupExistsOnServerResult = .failure(EncryptionFailure.sdk(Fixtures.sdkErrorInfo()))

        let repository = EncryptionRepository(service: service)

        await repository.refreshBackupExistence()

        #expect(repository.hasBackupOnServer == nil)
        #expect(repository.failure != nil)
    }

    // MARK: clearFailure()

    @Test("clearFailure resets the last failure without starting anything")
    func clearFailureResetsFailure() async {
        let service = MockEncryptionService()
        service.resetRecoveryKeyResult = .failure(EncryptionFailure.sdk(Fixtures.sdkErrorInfo()))

        let repository = EncryptionRepository(service: service)
        _ = await repository.resetRecoveryKey()

        #expect(repository.failure != nil)

        repository.clearFailure()

        #expect(repository.failure == nil)
    }

    // MARK: stop()

    @Test("stop() releases the service's listeners and allows a later restart")
    func stopReleasesListenersAndAllowsRestart() {
        let service = MockEncryptionService()
        let repository = EncryptionRepository(service: service)

        repository.start()
        repository.stop()

        #expect(service.shutdownCallCount == 1)

        repository.start()

        #expect(service.startCallCount == 2)
    }

    @Test("stop() stops forwarding stream values that arrive afterward")
    func stopStopsForwarding() async {
        let service = MockEncryptionService()
        let repository = EncryptionRepository(service: service)

        repository.start()

        // One value has to make it through before the forwarding task is cancelled, otherwise this
        // would not be testing cancellation at all: a value buffered before the loop's very first
        // iteration is handed over whatever the task's cancellation state.
        service.verificationStatusContinuation.yield(.unverified)
        await Eventually.isTrue { repository.verificationStatus == .unverified }

        repository.stop()

        service.verificationStatusContinuation.yield(.verified)

        await Eventually.isTrue(timeout: .milliseconds(200)) { repository.verificationStatus == .verified }

        #expect(repository.verificationStatus == .unverified)
    }
}
