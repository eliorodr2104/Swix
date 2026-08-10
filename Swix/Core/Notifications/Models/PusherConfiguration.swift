//
//  PusherConfiguration.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// Everything the homeserver needs in order to forward notifications to one device.
///
/// Registering a pusher is only half of push: the homeserver posts to `gatewayURL`, and it is that
/// gateway (Sygnal or equivalent) that talks to APNs. See `PusherService` for the whole picture.
struct PusherConfiguration: Equatable {

    /// The device token the gateway will push to, hex encoded for APNs.
    let pushKey: String

    /// The push application identifier the gateway is configured with, not the app bundle ID.
    let appID: String

    /// The gateway endpoint the homeserver posts notifications to.
    let gatewayURL: String

    /// The application name the homeserver shows in the user's device list.
    let appDisplayName: String

    /// This device's name, as shown next to the app name in the same list.
    let deviceDisplayName: String

    /// Optional string echoed back by the gateway, used to route several profiles to one device.
    let profileTag: String?

    /// The language notifications should be localized into by the homeserver.
    let language: String

    /// The JSON payload the gateway wraps every push in, encoded as a string.
    let defaultPayload: String?

    /// Whether to keep the account's other pushers. False replaces every pusher sharing this push
    /// key, which is what a single device app wants: one token, one pusher.
    let appendsToExistingPushers: Bool

    init(
        pushKey                 : String,
        appID                   : String,
        gatewayURL              : String,
        appDisplayName          : String,
        deviceDisplayName       : String,
        profileTag              : String?,
        language                : String,
        defaultPayload          : String?,
        appendsToExistingPushers: Bool
    ) {
        self.pushKey                  = pushKey
        self.appID                    = appID
        self.gatewayURL               = gatewayURL
        self.appDisplayName           = appDisplayName
        self.deviceDisplayName        = deviceDisplayName
        self.profileTag               = profileTag
        self.language                 = language
        self.defaultPayload           = defaultPayload
        self.appendsToExistingPushers = appendsToExistingPushers
    }

    /// The Sygnal deployment Swix pushes through. Replace it with your own once the gateway from
    /// the README's push setup is running.
    static let defaultGatewayURL = "https://matrix.org/_matrix/push/v1/notify"

    /// The payload every push carries, which asks iOS to hand the notification to an extension
    /// before showing it. Without `mutable-content` the encrypted placeholder is what the user sees.
    static let defaultPayload = #"{"aps":{"mutable-content":1,"alert":{"loc-key":"Notification","loc-args":[]}}}"#

    /// Builds the configuration for an APNs registration from the token `UIApplication` hands back.
    static func forAPNs(
        deviceToken       : Data,
        appID             : String,
        gatewayURL        : String = defaultGatewayURL,
        deviceDisplayName : String = MatrixConfiguration.clientName,
        language          : String = Locale.current.identifier
    ) -> PusherConfiguration {
        PusherConfiguration(
            pushKey                 : deviceToken.map { String(format: "%02x", $0) }.joined(),
            appID                   : appID,
            gatewayURL              : gatewayURL,
            appDisplayName          : MatrixConfiguration.clientName,
            deviceDisplayName       : deviceDisplayName,
            profileTag              : nil,
            language                : language,
            defaultPayload          : defaultPayload,
            appendsToExistingPushers: false
        )
    }
}
