//
//  CallSession.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation

/// A live Element Call session, ready to be hosted in a WKWebView.
///
/// `widgetURL` is the page to load. `messagesToWebView` and `postMessage` are the whole message
/// channel surface a UI layer needs: forward every element the stream yields into the webview's
/// JavaScript, and forward every message the webview's script handler receives into `postMessage`.
/// Neither side is an SDK type, so a view model can hold this without ever importing MatrixRustSDK.
struct CallSession {

    /// The room this call belongs to.
    let roomID: String

    /// The initial page for the WKWebView to load.
    let widgetURL: URL

    /// Messages the widget driver wants delivered to the webview, in delivery order.
    let messagesToWebView: AsyncStream<CallWidgetMessage>

    /// Forwards a message from the webview to the widget driver. Returns false once the driver
    /// backing this session has stopped, at which point the caller should treat the call as over.
    let postMessage: (CallWidgetMessage) async -> Bool
}
