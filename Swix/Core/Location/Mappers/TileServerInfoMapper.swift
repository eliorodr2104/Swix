//
//  TileServerInfoMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK


/// Turns the SDK's tile server advertisement into its Core equivalent.
enum TileServerInfoMapper {

    static func makeTileServerInfo(from sdkInfo: MatrixRustSDK.TileServerInfo?) -> TileServerInfo? {
        guard let sdkInfo else {
            return nil
        }

        return TileServerInfo(mapStyleUrl: sdkInfo.mapStyleUrl)
    }
}
