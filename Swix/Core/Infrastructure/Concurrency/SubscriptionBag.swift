//
//  SubscriptionBag.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// Retains every live listener registration for a scope (a repository, a service, a view model)
/// and tears them all down together, instead of scattering `TaskHandle`/`Task` fields everywhere.
final class SubscriptionBag {

    private var subscriptions: [any CancellableSubscription] = []
    private var tasks: [Task<Void, Never>] = []

    init() {}

    /// Keeps an SDK listener handle (or any other cancellable) alive until `cancelAll()`.
    func retain(_ subscription: any CancellableSubscription) {
        subscriptions.append(subscription)
    }

    /// Keeps a Swift structured concurrency task alive until `cancelAll()`.
    func retain(_ task: Task<Void, Never>) {
        tasks.append(task)
    }

    /// Cancels and forgets everything retained so far. Safe to call more than once.
    ///
    /// Owners must call this explicitly on teardown: a MainActor-isolated deinit cannot safely
    /// touch isolated storage, so there is deliberately no cleanup-on-deinit here.
    func cancelAll() {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()

        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
