//
//  MatrixImage.swift
//  Swix
//
//  Created by Eliomar on 11/08/2026.
//

import os
import SwiftUI


/// Loads a piece of Matrix media and hands every rendering decision to its caller, the way
/// `AsyncImage` does for the web.
///
/// A plain URL loader cannot do this job: Matrix media lives behind mxc URIs and the account's
/// access token, so the bytes come through the Core's media service, which authenticates and keeps
/// its own disk cache. On top of that sits a small in memory cache of decoded images, which is what
/// keeps a scrolling chat list from decoding the same avatar over and over.
///
///     MatrixImage(mediaURI: summary.avatarURL?.absoluteString) { phase in
///         switch phase {
///             case .success(let image): image.resizable().scaledToFill()
///             case .empty             : Color(.secondarySystemFill)
///             case .failure           : MonogramView(name: summary.name)
///         }
///     }
///     .frame(width: 44, height: 44)
///     .clipShape(.circle)
struct MatrixImage<Content: View>: View {

    /// The mxc URI of the media, straight from a summary or an event. Nil renders as `.failure`,
    /// so screens can bind optional avatars without unwrapping first.
    let mediaURI: String?

    /// The rendition to download, a thumbnail unless the caller says otherwise.
    var variant: MatrixImageVariant = .thumbnail(CGSize(width: 120, height: 120))

    /// Builds whatever the caller wants to show for each phase of the load.
    @ViewBuilder
    let content: (MatrixImagePhase) -> Content

    @Environment(\.mediaService)
    private var mediaService

    /// Thumbnails are requested in pixels, so the point size the layout thinks in has to be
    /// multiplied by the screen's scale or every avatar would arrive at a third of its sharpness.
    @Environment(\.displayScale)
    private var displayScale

    @State
    private var phase: MatrixImagePhase = .empty

    var body: some View {

        content(currentPhase)
            .task(id: loadIdentity) {
                await load()
            }
    }

    /// What the content sees right now: the decoded cache answers synchronously, so a cell coming
    /// back on screen shows its image on the very first frame instead of blinking through empty.
    private var currentPhase: MatrixImagePhase {

        if case .empty = phase, let cached = Self.decodedImages.object(forKey: cacheKey) {
            return .success(Image(uiImage: cached))
        }

        return phase
    }

    /// Everything that, by changing, invalidates the current load and starts another.
    private var loadIdentity: String {

        "\(mediaURI ?? "none")|\(variantIdentity)|\(displayScale)"
    }

    private var variantIdentity: String {

        switch variant {
            case .thumbnail(let size): "t\(Int(size.width))x\(Int(size.height))"
            case .original           : "o"
        }
    }

    private var cacheKey: NSString {

        loadIdentity as NSString
    }

    private func load() async {

        if let cached = Self.decodedImages.object(forKey: cacheKey) {
            phase = .success(Image(uiImage: cached))

            return
        }

        // A reused cell keeps the previous identity's phase until this load lands, so anything
        // stale goes back to empty rather than showing the wrong image in the meantime.
        if case .success = phase {
            phase = .empty
        }

        guard let mediaURI else {
            phase = .failure

            return
        }

        guard let mediaService else {
            Log.media.error("MatrixImage has no media service in the environment")

            phase = .failure

            return
        }

        do {
            let item = try MediaSourceMapper.makeMediaItem(mediaURI: mediaURI)
            let data = try await fetch(item, using: mediaService)

            guard !Task.isCancelled else {
                return
            }

            guard let decoded = UIImage(data: data) else {
                Log.media.error("Media \(mediaURI, privacy: .private) arrived but did not decode as an image")

                phase = .failure

                return
            }

            Self.decodedImages.setObject(
                decoded,
                forKey: cacheKey,
                cost  : data.count
            )

            phase = .success(Image(uiImage: decoded))
        } catch {
            guard !Task.isCancelled else {
                return
            }

            Log.media.error("MatrixImage load failed for \(mediaURI, privacy: .private): \(String(reflecting: error), privacy: .public)")

            phase = .failure
        }
    }

    private func fetch(
        _ item : MediaItem,
        using service: any MediaServiceProtocol
    ) async throws -> Data {

        switch variant {
            case .thumbnail(let size):
                try await service.thumbnail(
                    for   : item,
                    width : Int(size.width * displayScale),
                    height: Int(size.height * displayScale)
                )

            case .original:
                try await service.content(for: item)
        }
    }

    /// Decoded images shared by every `MatrixImage` in the process, capped so a long scroll
    /// through image heavy rooms cannot grow it without bound. Cost is the encoded byte count.
    private static var decodedImages: NSCache<NSString, UIImage> {
        MatrixImageCache.shared
    }
}


/// The one process wide cache instance, kept outside the generic type because every `Content`
/// specialization of `MatrixImage` would otherwise get a static of its own.
private enum MatrixImageCache {

    static let shared: NSCache<NSString, UIImage> = {

        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024

        return cache
    }()
}
