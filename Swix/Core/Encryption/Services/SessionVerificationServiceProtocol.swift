//
//  SessionVerificationServiceProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// Drives one interactive SAS verification, in either direction, and reports what the other side
/// does as domain events.
///
/// The controller is a single flow at a time by construction: the SDK keeps one active request per
/// controller, so acknowledging a new incoming request replaces whatever was running.
protocol SessionVerificationServiceProtocol {

    /// Everything the controller reported, already stripped of SDK types.
    var events: AsyncStream<VerificationEvent> { get }

    /// Obtains the controller and registers for its callbacks. Safe to call more than once.
    func start() async throws

    /// Asks the account's other sessions to verify this device.
    func requestDeviceVerification() async throws

    /// Asks another user to verify their identity with ours.
    func requestUserVerification(userID: String) async throws

    /// Makes an incoming request the active one. Nothing else about that flow is reported until
    /// this has run, which is why it happens as soon as the request arrives.
    func acknowledgeRequest(senderID: String, flowID: String) async throws

    /// Accepts the acknowledged incoming request.
    func acceptRequest() async throws

    /// Moves the accepted request into the short authentication string exchange.
    func startSas() async throws

    /// Confirms that the emojis match on both devices.
    func approve() async throws

    /// Rejects the emojis, which tells the other side the devices do not match.
    func decline() async throws

    /// Abandons the flow.
    func cancel() async throws

    /// Releases the controller and its delegate. Called once, when the session ends.
    func shutdown()
}