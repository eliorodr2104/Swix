//
//  LastKnownLocation.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// The most recent position behind an active live share, and when it was recorded.
struct LastKnownLocation: Equatable {

    /// Where the beacon last reported being.
    let position: LocationPayload

    /// When that position was recorded by the sender's device, not when this device found out
    /// about it.
    let timestamp: Date
}
