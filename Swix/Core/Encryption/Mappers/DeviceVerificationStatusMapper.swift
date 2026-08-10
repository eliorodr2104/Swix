//
//  DeviceVerificationStatusMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK

/// Turns the SDK's device trust state into the Core domain equivalent.
enum DeviceVerificationStatusMapper {

    /// Maps `VerificationState`. Core never repeats the SDK vocabulary verbatim, so a future
    /// release adding a case fails to compile here instead of silently mislabeling trust.
    static func makeStatus(from state: VerificationState) -> DeviceVerificationStatus {
        switch state {
            case .unknown   : .unknown
            case .verified  : .verified
            case .unverified: .unverified
        }
    }
}
