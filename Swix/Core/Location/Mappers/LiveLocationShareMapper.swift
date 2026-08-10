//
//  LiveLocationShareMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation
import MatrixRustSDK


/// Turns the SDK's live location share type, and the diffs `LiveLocationsObserver` reports them
/// through, into their Core equivalents.
///
/// The eleven diff cases are the same eleven the room list and every timeline use, which is why
/// they land in the shared `CollectionDiff` instead of a type of their own.
enum LiveLocationShareMapper {

    static func makeShare(from sdkShare: MatrixRustSDK.LiveLocationShare) -> LiveLocationShare {
        LiveLocationShare(
            userID   : sdkShare.userId,
            lastKnown: makeLastKnown(from: sdkShare.lastLocation),
            expiresAt: Date(timeIntervalSince1970: Double(sdkShare.startTs + sdkShare.timeout) / 1000)
        )
    }

    /// Maps one batch of SDK diffs, preserving its order, so the repository can apply it as a
    /// single atomic update.
    static func makeDiffs(from updates: [LiveLocationShareUpdate]) -> [CollectionDiff<LiveLocationShare>] {
        updates.map(makeDiff)
    }

    private static func makeDiff(from update: LiveLocationShareUpdate) -> CollectionDiff<LiveLocationShare> {
        switch update {
            case .append(let values): .append(values.map(makeShare))
            case .clear: .clear
            case .pushFront(let value): .pushFront(makeShare(from: value))
            case .pushBack(let value): .pushBack(makeShare(from: value))
            case .popFront: .popFront
            case .popBack: .popBack
            case .insert(let index, let value): .insert(index: Int(index), element: makeShare(from: value))
            case .set(let index, let value): .set(index: Int(index), element: makeShare(from: value))
            case .remove(let index): .remove(index: Int(index))
            case .truncate(let length): .truncate(length: Int(length))
            case .reset(let values): .reset(values.map(makeShare))
        }
    }

    private static func makeLastKnown(from lastLocation: MatrixRustSDK.LastLocation?) -> LastKnownLocation? {
        guard
            let lastLocation,
            let position = LocationPayloadMapper.makePayload(from: lastLocation.location)
        else {
            return nil
        }

        return LastKnownLocation(
            position : position,
            timestamp: Date(timeIntervalSince1970: Double(lastLocation.ts) / 1000)
        )
    }
}
