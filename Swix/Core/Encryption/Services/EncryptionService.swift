//
//  EncryptionService.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK
import os


/// The default `EncryptionServiceProtocol`, built on `Client.encryption()`.
final class EncryptionService: EncryptionServiceProtocol {

    let verificationStatusStream: AsyncStream<DeviceVerificationStatus>

    let recoveryStatusStream: AsyncStream<RecoveryStatus>

    let backupStatusStream: AsyncStream<KeyBackupStatus>

    let recoveryProgressStream: AsyncStream<RecoveryProgress>

    private let clientService: any ClientServiceProtocol

    private let verificationContinuation: AsyncStream<DeviceVerificationStatus>.Continuation

    private let recoveryContinuation: AsyncStream<RecoveryStatus>.Continuation

    private let backupContinuation: AsyncStream<KeyBackupStatus>.Continuation

    private let progressContinuation: AsyncStream<RecoveryProgress>.Continuation

    private let subscriptions = SubscriptionBag()

    // The Encryption object is kept for the whole session: it is what the three listeners were
    // registered on, and asking the client for a new one would leave them pointing at the old one.
    private var encryption: Encryption?

    init(clientService: any ClientServiceProtocol) {
        self.clientService = clientService

        (verificationStatusStream, verificationContinuation) = AsyncStream<DeviceVerificationStatus>.makeStream(bufferingPolicy: .unbounded)
        (recoveryStatusStream, recoveryContinuation) = AsyncStream<RecoveryStatus>.makeStream(bufferingPolicy: .unbounded)
        (backupStatusStream, backupContinuation) = AsyncStream<KeyBackupStatus>.makeStream(bufferingPolicy: .unbounded)
        (recoveryProgressStream, progressContinuation) = AsyncStream<RecoveryProgress>.makeStream(bufferingPolicy: .unbounded)
    }

    var verificationStatus: DeviceVerificationStatus {
        guard let encryption else {
            return .unknown
        }

        return DeviceVerificationStatusMapper.makeStatus(from: encryption.verificationState())
    }

    var recoveryStatus: RecoveryStatus {
        guard let encryption else {
            return .unknown
        }

        return RecoveryStatusMapper.makeStatus(from: encryption.recoveryState())
    }

    var backupStatus: KeyBackupStatus {
        guard let encryption else {
            return .unknown
        }

        return KeyBackupStatusMapper.makeStatus(from: encryption.backupState())
    }

    func start() throws {
        guard encryption == nil else {
            return
        }

        guard let client = clientService.sdkClient else {
            throw EncryptionFailure.noActiveClient
        }

        let encryption = client.encryption()

        self.encryption = encryption

        observe(encryption)
        publishCurrentStates(of: encryption)
    }

    func recover(recoveryKey: String) async throws {
        let encryption = try activeEncryption()

        do {
            try await encryption.recover(recoveryKey: recoveryKey)
            
        } catch { throw Self.recoveryFailure(from: error) }

        Log.encryption.notice("Recovery key accepted, secret storage unlocked")
    }

    func enableRecovery(
        waitForBackupsToUpload: Bool,
        passphrase            : String?
    ) async throws -> String {
    
        let encryption = try activeEncryption()
        let (progressStream, listener) = makeSDKStream(of: EnableRecoveryProgress.self)

        forwardEnableRecoveryProgress(from: progressStream)

        do {
            let key = try await encryption.enableRecovery(
                waitForBackupsToUpload: waitForBackupsToUpload,
                passphrase            : passphrase,
                progressListener      : listener
            )

            Log.encryption.notice("Recovery enabled")

            return key
            
        } catch { throw Self.recoveryFailure(from: error) }
    }

    func resetRecoveryKey() async throws -> String {
        let encryption = try activeEncryption()

        do {
            return try await encryption.resetRecoveryKey()
            
        } catch { throw Self.recoveryFailure(from: error) }
    }

    func disableRecovery() async throws {
        let encryption = try activeEncryption()

        do {
            try await encryption.disableRecovery()
            
        } catch { throw Self.recoveryFailure(from: error) }
    }

    func backupExistsOnServer() async throws -> Bool {
        let encryption = try activeEncryption()

        do {
            return try await encryption.backupExistsOnServer()
            
        } catch { throw EncryptionFailure.backupFailed(SDKErrorInfo(error)) }
    }

    func waitForBackupUploadSteadyState() async throws {
        let encryption = try activeEncryption()
        let (uploadStream, listener) = makeSDKStream(of: BackupUploadState.self)

        subscriptions.retain(
            Task { [progressContinuation] in
                for await state in uploadStream {
                    progressContinuation.yield(
                        KeyBackupStatusMapper.makeProgress(from: state)
                    )
                }
            }
        )

        do {
            try await encryption.waitForBackupUploadSteadyState(progressListener: listener)
            
        } catch { throw EncryptionFailure.backupFailed(SDKErrorInfo(error)) }
    }

    func waitForE2eeInitializationTasks() async {
        guard let encryption else {
            return
        }

        await encryption.waitForE2eeInitializationTasks()
    }

    func shutdown() {
        subscriptions.cancelAll()
        encryption = nil
    }

    /// Attaching lazily here means a screen can call an operation without having had to start the
    /// service first, which is what makes the recovery sheet usable on its own.
    private func activeEncryption() throws -> Encryption {
        try start()

        guard let encryption else {
            throw EncryptionFailure.noActiveClient
        }

        return encryption
    }

    private func observe(_ encryption: Encryption) {
        let (verificationStates, verificationListener) = makeSDKStream(of: VerificationState.self)

        subscriptions.retain(
            encryption.verificationStateListener(listener: verificationListener)
        )
        
        subscriptions.retain(
            Task { [verificationContinuation] in
                for await state in verificationStates {
                    verificationContinuation.yield(
                        DeviceVerificationStatusMapper.makeStatus(from: state)
                    )
                }
            }
        )

        let (recoveryStates, recoveryListener) = makeSDKStream(of: RecoveryState.self)

        subscriptions.retain(
            encryption.recoveryStateListener(listener: recoveryListener)
        )
        
        subscriptions.retain(
            Task { [recoveryContinuation] in
                for await state in recoveryStates {
                    recoveryContinuation.yield(
                        RecoveryStatusMapper.makeStatus(from: state)
                    )
                }
            }
        )

        let (backupStates, backupListener) = makeSDKStream(of: BackupState.self)

        subscriptions.retain(encryption.backupStateListener(listener: backupListener))
        subscriptions.retain(
            Task { [backupContinuation] in
                for await state in backupStates {
                    backupContinuation.yield(
                        KeyBackupStatusMapper.makeStatus(from: state)
                    )
                }
            }
        )
    }

    /// The SDK listeners only report changes, so whoever subscribes after `start()` would sit on
    /// `.unknown` until something moved. Publishing the current values closes that gap.
    private func publishCurrentStates(of encryption: Encryption) {
        verificationContinuation.yield(
            DeviceVerificationStatusMapper.makeStatus(from: encryption.verificationState())
        )
        
        recoveryContinuation.yield(
            RecoveryStatusMapper.makeStatus(from: encryption.recoveryState())
        )
        
        backupContinuation.yield(
            KeyBackupStatusMapper.makeStatus(from: encryption.backupState())
        )
    }

    /// The forwarding task is retained rather than cancelled when `enableRecovery` returns: the
    /// stream ends by itself when Rust releases the listener, which is what delivers the last
    /// progress value.
    private func forwardEnableRecoveryProgress(
        from stream: AsyncStream<EnableRecoveryProgress>
    ) {
    
        subscriptions.retain(
            Task { [progressContinuation] in
                for await progress in stream {
                    progressContinuation.yield(
                        RecoveryStatusMapper.makeProgress(from: progress)
                    )
                }
            }
        )
    }

    /// A recovery key that does not open secret storage surfaces as a secret storage or import
    /// error, which is the one failure the user can actually do something about.
    private static func recoveryFailure(from error: any Error) -> EncryptionFailure {
        let info = SDKErrorInfo(error)

        guard let recoveryError = error as? RecoveryError else {
            return .recoveryFailed(info)
        }

        switch recoveryError {
            case .SecretStorage, .Import: return .invalidRecoveryKey(info)
            default: return .recoveryFailed(info)
        }
    }
}
