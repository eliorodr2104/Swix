//
//  CallWidgetSettingsMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK

/// Turns the domain `CallWidgetConfiguration` into the two structs `newVirtualElementCallWidget`
/// needs, splitting them exactly the way the SDK does: fixed identity in the properties, tunable
/// behavior in the config.
enum CallWidgetSettingsMapper {

    /// Builds the widget's identity and encryption settings. `widgetID` must be unique per call.
    static func makeWidgetProperties(
        configuration: CallWidgetConfiguration,
        widgetID     : String
    ) -> VirtualElementCallWidgetProperties {
        
        VirtualElementCallWidgetProperties(
            elementCallUrl: configuration.baseURL,
            widgetId      : widgetID,
            encryption    : makeEncryptionSystem(from: configuration.encryption)
        )
    }

    /// Builds the widget's behavioral configuration: intent, lobby, header and confinement.
    static func makeWidgetConfig(
        configuration: CallWidgetConfiguration
    ) -> VirtualElementCallWidgetConfig {
        
        VirtualElementCallWidgetConfig(
            intent       : makeIntent(from: configuration.intent),
            skipLobby    : configuration.skipLobby,
            hideHeader   : !configuration.showHeader,
            preload      : configuration.preload,
            confineToRoom: configuration.confineToRoom
        )
    }

    private static func makeIntent(from intent: CallIntent) -> Intent {
        switch intent {
            case .startCall   : .startCall
            case .joinExisting: .joinExisting
        }
    }

    private static func makeEncryptionSystem(
        from mode: CallEncryptionMode
    ) -> EncryptionSystem {
    
        switch mode {
            case .unencrypted             : .unencrypted
            case .perParticipantKeys      : .perParticipantKeys
            case .sharedSecret(let secret): .sharedSecret(secret: secret)
        }
    }
}
