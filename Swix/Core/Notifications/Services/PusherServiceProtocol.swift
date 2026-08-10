//
//  PusherServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Tells the homeserver where to forward this device's notifications, and stops telling it.
///
/// Registering a pusher is the only part of push delivery that lives in the app. The homeserver
/// posts to a push gateway (Sygnal or equivalent) and the gateway is what holds the APNs
/// certificate, so nothing arrives on the device until three things exist outside this code: the
/// push entitlement on the Apple Developer account, a Notification Service Extension target able to
/// decrypt the event referenced by an `eventIdOnly` push, and a gateway configured with the same
/// app ID this service registers. Until then a registration succeeds and simply never delivers.
protocol PusherServiceProtocol {

    /// Registers or refreshes this device's pusher. Safe to call on every launch: the homeserver
    /// treats a repeated push key as an update rather than as a duplicate.
    func registerPusher(_ configuration: PusherConfiguration) async throws

    /// Removes the pusher, which is what signing out has to do before the tokens are dropped.
    func unregisterPusher(_ configuration: PusherConfiguration) async throws
}
