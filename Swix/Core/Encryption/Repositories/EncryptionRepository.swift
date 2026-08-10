//
//  EncryptionRepository.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation
import os

/// The single source of truth for how protected this account is: whether the device is trusted,
/// whether there is a recovery key, and whether the room keys are backed up.
@Observable
final class EncryptionRepository {

    /// Trust state of this device. Views observe this through a view model.
    private(set) var verificationStatus: DeviceVerificationStatus = .unknown

    /// Whether the account has a usable recovery key.
    private(set) var recoveryStatus: RecoveryStatus = .unknown

    /// Where the server side room key backup stands.
    private(set) var backupStatus: KeyBackupStatus = .unknown

    /// Progress of the recovery or backup operation in flight, nil when nothing is running.
    private(set) var recoveryProgress: RecoveryProgress?

    /// Whether a backup version exists on the homeserver, nil until it has been asked for.
    ///
    /// This is the only way to tell "no backup at all" from "a backup this device cannot read",
    /// both of which the SDK reports as `.unknown`.
    private(set) var hasBackupOnServer: Bool?

    /// The last failure an operation raised, kept until the next attempt clears it.
    private(set) var failure: EncryptionFailure?

    @ObservationIgnored
    private let service: any EncryptionServiceProtocol

    @ObservationIgnored
    private let subscriptions = SubscriptionBag()

    @ObservationIgnored
    private var isObserving = false

    init(service: any EncryptionServiceProtocol) {
        self.service = service
    }

    /// Attaches to the live client and begins mirroring the three encryption states.
    ///
    /// Doing nothing on a second call is what makes this safe to invoke both from the app entry
    /// point and from any screen that happens to appear first.
    func start() {
        guard !isObserving else {
            return
        }

        do {
            try service.start()
        } catch {
            record(error)

            return
        }

        isObserving = true

        observeStates()
        readCurrentStates()
        awaitInitializationTasks()
    }

    /// Releases every subscription this repository and its service own. Called once, by the scope
    /// that created them, when the session ends.
    func stop() {
        subscriptions.cancelAll()
        service.shutdown()

        isObserving = false
    }

    /// Unlocks secret storage with a recovery key the user typed. Returns whether it worked.
    @discardableResult
    func recover(withKey recoveryKey: String) async -> Bool {
        failure = nil

        do {
            try await service.recover(recoveryKey: recoveryKey)

            readCurrentStates()

            return true
            
        } catch {
            record(error)

            return false
        }
    }

    /// Produces a recovery key for the account, whatever state recovery is in.
    ///
    /// Enabling and resetting are two different SDK calls that the user experiences as one button,
    /// and calling the wrong one fails: enabling refuses to overwrite an existing backup.
    func generateRecoveryKey(passphrase: String? = nil) async -> String? {
        switch recoveryStatus {
            case .enabled, .incomplete: await resetRecoveryKey()
            case .unknown, .disabled  : await enableRecovery(passphrase: passphrase)
        }
    }

    /// Turns recovery on and hands back the generated key, which is shown to the user exactly once.
    func enableRecovery(
        waitForBackupsToUpload: Bool    = false,
        passphrase            : String? = nil
    ) async -> String? {
        failure = nil
        recoveryProgress = .starting

        defer {
            recoveryProgress = nil
        }

        do {
            let key = try await service.enableRecovery(
                waitForBackupsToUpload: waitForBackupsToUpload,
                passphrase            : passphrase
            )

            readCurrentStates()
            return key
            
        } catch {
            record(error)
            return nil
        }
    }

    /// Replaces the recovery key of an account that already has one, returning the new key.
    func resetRecoveryKey() async -> String? {
        failure = nil

        do {
            let key = try await service.resetRecoveryKey()

            readCurrentStates()
            return key
            
        } catch {
            record(error)
            return nil
        }
    }

    /// Removes recovery and the key backup from the homeserver.
    func disableRecovery() async {
        failure = nil

        do {
            try await service.disableRecovery()

            hasBackupOnServer = false
            readCurrentStates()
            
        } catch { record(error) }
    }

    /// Polls the homeserver for the existence of a backup version and publishes the answer.
    func refreshBackupExistence() async {
        do {
            hasBackupOnServer = try await service.backupExistsOnServer()
       
        } catch { record(error) }
    }

    /// Clears the last failure, so a screen can dismiss it without starting an operation.
    @inline(__always)
    func clearFailure() {
        failure = nil
    }

    private func observeStates() {
        subscriptions.retain(
            Task { [weak self, stream = service.verificationStatusStream] in
                for await status in stream {
                    // AsyncStream hands out buffered elements even to a cancelled consumer, so
                    // stop() alone cannot guarantee these loops never fire afterwards.
                    guard !Task.isCancelled else { break }

                    self?.verificationStatus = status
                }
            }
        )

        subscriptions.retain(
            Task { [weak self, stream = service.recoveryStatusStream] in
                for await status in stream {
                    guard !Task.isCancelled else { break }

                    self?.recoveryStatus = status
                }
            }
        )

        subscriptions.retain(
            Task { [weak self, stream = service.backupStatusStream] in
                for await status in stream {
                    guard !Task.isCancelled else { break }

                    self?.backupStatus = status
                }
            }
        )

        subscriptions.retain(
            Task { [weak self, stream = service.recoveryProgressStream] in
                for await progress in stream {
                    guard !Task.isCancelled else { break }

                    self?.recoveryProgress = progress
                }
            }
        )
    }

    private func readCurrentStates() {
        verificationStatus = service.verificationStatus
        recoveryStatus     = service.recoveryStatus
        backupStatus       = service.backupStatus
    }

    /// The SDK bootstraps cross signing and backups in the background right after a login, so the
    /// states read at startup are provisional until those tasks finish.
    private func awaitInitializationTasks() {
        subscriptions.retain(
            Task { [weak self, service] in
                await service.waitForE2eeInitializationTasks()

                self?.readCurrentStates()
            }
        )
    }

    private func record(_ error: any Error) {
        let encryptionFailure = EncryptionFailure.wrapping(error)

        Log.encryption.error("Encryption operation failed: \(String(reflecting: error), privacy: .public)")

        failure = encryptionFailure
    }
}
