//
//  OwnBeaconMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns the SDK's client wide beacon update into its Core equivalent.
enum OwnBeaconMapper {

    static func makeUpdate(from update: BeaconInfoUpdate) -> OwnBeaconShareUpdate {
        OwnBeaconShareUpdate(
            roomID : update.roomId,
            eventID: update.eventId,
            isLive : update.live
        )
    }
}
