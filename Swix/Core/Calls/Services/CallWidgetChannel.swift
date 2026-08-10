//
//  CallWidgetChannel.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK

/// Bridges one widget driver's two independent async loops onto `CallSession`'s message channel.
///
/// SERVICE LAYER ONLY: `CallWidgetService` is the sole owner of a channel. It never escapes past
/// `CallSession`'s SDK-free `messagesToWebView` stream and `postMessage` closure, which is what
/// keeps repositories and view models from ever seeing `WidgetDriver` or `WidgetDriverHandle`.
final class CallWidgetChannel {

    /// Messages the widget driver wants delivered to the webview, in delivery order.
    let messagesToWebView: AsyncStream<CallWidgetMessage>

    /// Called once, from the receive loop's own task, when `recv()` returns nil because the driver
    /// stopped on its own rather than through `stop()`.
    var onDriverStopped: (() -> Void)?

    private let driver: WidgetDriver

    private let handle: WidgetDriverHandle

    private let room: Room

    private let capabilitiesProvider: SDKWidgetCapabilitiesProvider

    private let messageContinuation: AsyncStream<CallWidgetMessage>.Continuation

    private let subscriptions = SubscriptionBag()

    init(
        driver              : WidgetDriver,
        handle              : WidgetDriverHandle,
        room                : Room,
        capabilitiesProvider: SDKWidgetCapabilitiesProvider
    ) {
        self.driver               = driver
        self.handle               = handle
        self.room                 = room
        self.capabilitiesProvider = capabilitiesProvider

        (messagesToWebView, messageContinuation) = AsyncStream<CallWidgetMessage>.makeStream(bufferingPolicy: .unbounded)
    }

    /// Starts the driver's own long running task and the loop that forwards its messages onward.
    func start() {
        subscriptions.retain(
            Task { [driver, room, capabilitiesProvider] in
                await driver.run(
                    room                : room,
                    capabilitiesProvider: capabilitiesProvider
                )
            }
        )

        subscriptions.retain(
            Task { [weak self, handle, messageContinuation] in
                while let raw = await handle.recv() {
                    guard let message = CallWidgetMessage(json: raw) else {
                        continue
                    }

                    messageContinuation.yield(message)
                }

                messageContinuation.finish()
                self?.onDriverStopped?()
            }
        )
    }

    /// Forwards a message from the webview to the widget driver. False means the driver stopped.
    func post(fromWebView message: CallWidgetMessage) async -> Bool {
        await handle.send(msg: message.json)
    }

    /// Cancels both tasks and finishes the outgoing stream. Safe to call more than once.
    func stop() {
        subscriptions.cancelAll()
        messageContinuation.finish()
    }
}
