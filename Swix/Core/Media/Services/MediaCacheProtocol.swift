//
//  MediaCacheProtocol.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// A bounded on disk store for media the app can always fetch again.
protocol MediaCacheProtocol {

    /// Returns the cached bytes for `key`, marking the entry as the most recently used one.
    func data(forKey key: String) -> Data?

    /// Writes `data` under `key`, evicting older entries if that pushes the cache over its budget.
    func store(_ data: Data, forKey key: String)

    /// Drops everything, for example when the user signs out.
    func removeAll()

    /// How much disk the cache is using right now.
    var currentByteCount: Int { get }
}
