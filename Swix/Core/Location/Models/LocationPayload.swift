//
//  LocationPayload.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// A single point on the map: either a one-shot share of where the sender is right now, or the
/// snapshot behind a live share's latest beacon update.
struct LocationPayload: Equatable {

    /// Latitude in decimal degrees, WGS 84.
    let latitude: Double

    /// Longitude in decimal degrees, WGS 84.
    let longitude: Double

    /// A human readable label for the point, shown next to the pin when the sender chose one.
    let description: String?

    /// How closely the map should be zoomed when first centering on this point, 0 (whole world) to
    /// 20 (building level), the same scale the `geo:` URI specification defines. Absent when the
    /// sender left the choice to whatever the receiving client defaults to.
    let zoomLevel: UInt8?

    init(
        latitude   : Double,
        longitude  : Double,
        description: String? = nil,
        zoomLevel  : UInt8? = nil
    ) {
        self.latitude    = latitude
        self.longitude   = longitude
        self.description = description
        self.zoomLevel   = zoomLevel
    }

    /// The `geo:` URI every Matrix client expects a location event's coordinates in, built here
    /// rather than trusted from the network so a sender can never hand the SDK a malformed one.
    var geoUri: String {
        "geo:\(latitude),\(longitude)"
    }
}
