//
//  SyncLifecycleController.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// The default `SyncLifecycleControllerProtocol`, driving a `SyncRepository`.
///
/// Going to `.background` does not stop sync immediately: a brief interruption, like the control
/// center being pulled down, reports `.inactive` and then `.active` again within a second, and
/// tearing sync down for that would waste a reconnect for no reason. The stop only actually
/// happens once `backgroundGraceDelay` has elapsed without the app coming back to the foreground.
final class SyncLifecycleController: SyncLifecycleControllerProtocol {

    private let repository: SyncRepository

    private let backgroundGraceDelay: Duration

    private var pendingStopTask: Task<Void, Never>?

    init(
        repository          : SyncRepository,
        backgroundGraceDelay: Duration = .seconds(10)
    ) {
        self.repository           = repository
        self.backgroundGraceDelay = backgroundGraceDelay
    }

    func handle(scenePhase: AppScenePhase) {
        switch scenePhase {
            case .active, .inactive:
                cancelPendingStop()

                Task { await repository.start() }

            case .background:
                scheduleStop()
        }
    }

    func invalidate() {
        cancelPendingStop()
    }

    private func scheduleStop() {
        cancelPendingStop()

        let delay = backgroundGraceDelay

        pendingStopTask = Task { [weak self] in
            try? await Task.sleep(for: delay)

            guard !Task.isCancelled else {
                return
            }

            await self?.repository.stop()
        }
    }

    private func cancelPendingStop() {
        pendingStopTask?.cancel()
        pendingStopTask = nil
    }
}
