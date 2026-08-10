//
//  CallWidgetMessage.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

/// One widget-api JSON message flowing between the Element Call webview and its driver.
///
/// The type is a thin wrapper rather than a parsed payload on purpose: the widget-api protocol is
/// entirely owned by the webview's own JavaScript and the SDK's widget driver, so Core only ever
/// needs to move the raw string across the boundary without understanding its shape.
struct CallWidgetMessage: Equatable {

    /// The message body, exactly as sent or received.
    let json: String

    /// Fails for an empty string, since an empty message can never be valid widget-api JSON and
    /// would otherwise silently confuse whichever side receives it.
    init?(json: String) {
        guard !json.isEmpty else { return nil }

        self.json = json
    }
}
