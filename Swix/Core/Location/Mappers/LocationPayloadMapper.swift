//
//  LocationPayloadMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Builds the pieces the SDK's `sendLocation` wants out of a `LocationPayload`, and reads a
/// `LocationContent` the SDK reported back into one.
enum LocationPayloadMapper {

    /// The fallback text homeserver push previews and clients without map support show instead of
    /// the pin: the sender's own label when they gave one, otherwise the bare coordinates.
    static func makeBody(from payload: LocationPayload) -> String {
        payload.description ?? "Location: \(payload.geoUri)"
    }

    /// Reads a beacon's reported content back into a payload, nil when its `geo:` URI cannot be
    /// parsed.
    static func makePayload(from content: LocationContent) -> LocationPayload? {
        guard let coordinates = makeCoordinates(from: content.geoUri) else {
            return nil
        }

        return LocationPayload(
            latitude   : coordinates.latitude,
            longitude  : coordinates.longitude,
            description: content.description,
            zoomLevel  : content.zoomLevel
        )
    }

    /// Parses a `geo:` URI's latitude and longitude, ignoring any uncertainty parameter after the
    /// semicolon. Malformed input maps to nil rather than crashing: a beacon a homeserver relayed
    /// wrong should disappear from the map, not the app.
    private static func makeCoordinates(
        from geoUri: String
    ) -> (latitude: Double, longitude: Double)? {

        let withoutScheme = geoUri.hasPrefix("geo:") ? String(geoUri.dropFirst(4)) : geoUri
        let withoutParameters = withoutScheme.split(separator: ";", maxSplits: 1).first.map(String.init) ?? withoutScheme
        let parts = withoutParameters.split(separator: ",")

        guard
            parts.count >= 2,
            let latitude = Double(parts[0]),
            let longitude = Double(parts[1])
        else {
            return nil
        }

        return (latitude, longitude)
    }
}
