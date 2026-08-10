//
//  UserFacingFailure.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import Foundation


/// The only error shape view models are allowed to hold, so views never see a raw `Error`.
struct UserFacingFailure: Equatable, Identifiable {

    let id: UUID
    let title: String
    let message: String
    let isRetryable: Bool

    init(
        id         : UUID = UUID(),
        title      : String,
        message    : String,
        isRetryable: Bool
    ) {
        self.id          = id
        self.title       = title
        self.message     = message
        self.isRetryable = isRetryable
    }
}
