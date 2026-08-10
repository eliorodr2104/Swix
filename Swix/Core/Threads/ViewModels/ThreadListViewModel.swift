//
//  ThreadListViewModel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Observation


/// Everything the thread list screen binds to: the rows, whether more are on the way, and what to
/// say when the homeserver refuses.
@Observable
final class ThreadListViewModel {

    /// The failure to present. Views clear it by setting it back to nil.
    var failure: UserFacingFailure?

    @ObservationIgnored
    private let repository: ThreadListRepository

    init(repository: ThreadListRepository) {
        self.repository = repository
    }

    /// The room whose threads are on screen.
    var roomID: String {
        repository.roomID
    }

    /// Every thread to render, in the order the homeserver paginated them.
    var threads: [ThreadEntry] {
        repository.threads
    }

    /// Whether the room has no threads, so the screen can offer its empty state.
    var isEmpty: Bool {
        repository.isEmpty
    }

    /// Whether a page is on its way, for the spinner at the end of the list.
    var isLoading: Bool {
        repository.state.isLoading
    }

    /// Whether reaching the end of the list should ask for one more page.
    var canLoadMore: Bool {
        repository.state.canLoadMore
    }

    /// Builds the list and loads its first page. Called when the screen appears.
    func start() async {
        await repository.start()

        updateFailure()
    }

    /// Loads the next page. Called when the last row appears.
    func loadMore() async {
        await repository.loadMore()

        updateFailure()
    }

    /// Throws the list away and loads it again, for a pull to refresh.
    func refresh() async {
        await repository.refresh()

        updateFailure()
    }

    /// Reads whether the account follows one thread, for a row that is about to offer its toggle.
    func loadSubscription(for entry: ThreadEntry) async {
        await repository.loadSubscription(forThread: entry.rootEventID)

        updateFailure()
    }

    /// Follows the thread, or stops following it when the account already does.
    ///
    /// A row whose subscription has never been read is asked about instead of flipped: acting on a
    /// guess would take the user somewhere they did not choose.
    func toggleSubscription(for entry: ThreadEntry) async {
        guard entry.subscription.isKnown else {
            await loadSubscription(for: entry)

            return
        }

        await repository.setSubscription(!entry.isSubscribed, forThread: entry.rootEventID)

        updateFailure()
    }

    /// Tears the list down when the screen goes away.
    func shutdown() {
        failure = nil

        repository.shutdown()
    }

    private func updateFailure() {
        guard let threadsFailure = repository.failure else {
            failure = nil

            return
        }

        failure = UserFacingFailure(
            title      : Self.title(for: threadsFailure),
            message    : threadsFailure.message,
            isRetryable: threadsFailure.isRetryable
        )
    }

    private static func title(for failure: ThreadsFailure) -> String {
        switch failure {
            case .notStarted: "The threads are not ready yet"
            case .roomUnavailable: "That conversation is gone"
            case .listUnavailable: "Could not load the threads"
            case .paginationFailed: "Could not load more threads"
            case .threadUnavailable: "Could not open this thread"
            case .subscriptionFailed: "Could not change what this thread notifies you about"
        }
    }
}
