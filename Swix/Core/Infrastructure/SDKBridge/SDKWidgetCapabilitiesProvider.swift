//
//  SDKWidgetCapabilitiesProvider.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Answers the widget driver's capability negotiation for an Element Call widget.
///
/// The driver asks synchronously while starting the call, so the answer is the fixed permission set
/// Element Call needs rather than anything the user has to be prompted for.
nonisolated final class SDKWidgetCapabilitiesProvider: WidgetCapabilitiesProvider {

    private let ownUserID: String

    private let ownDeviceID: String

    init(
        ownUserID  : String,
        ownDeviceID: String
    ) {
        self.ownUserID = ownUserID
        self.ownDeviceID = ownDeviceID
    }

    /// Grants exactly the permissions Element Call requires, ignoring what the widget asked for.
    func acquireCapabilities(capabilities: WidgetCapabilities) -> WidgetCapabilities {
        getElementCallRequiredPermissions(ownUserId: ownUserID, ownDeviceId: ownDeviceID)
    }
}
