//
//  MediaScanMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns content scanner answers, successful or not, into a `ScanVerdict`.
enum MediaScanMapper {

    /// Maps a completed scan.
    static func makeVerdict(from response: MediaScanResponse) -> ScanVerdict {
        response.clean ? .clean(info: response.info) : .infected(info: response.info)
    }

    /// Recovers the verdict hidden inside a thrown error.
    ///
    /// A scanner that rejects a file reports it as a `ContentScanner` error rather than as a dirty
    /// response, so treating every throw as a transport failure would lose the actual answer.
    static func makeVerdict(from error: any Error) -> ScanVerdict? {
        guard let clientError = error as? ClientError,
              case .ContentScanner(let reason, let info) = clientError else {
            return nil
        }

        switch reason {
            case .mcsMediaNotClean, .mcsMimeTypeForbidden: return .infected(info: info)
            default: return nil
        }
    }
}
