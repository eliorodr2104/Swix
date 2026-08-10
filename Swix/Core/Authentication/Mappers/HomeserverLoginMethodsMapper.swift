//
//  HomeserverLoginMethodsMapper.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//

import MatrixRustSDK

/// Turns the SDK's login details handle into the domain value the login screen reasons about.
enum HomeserverLoginMethodsMapper {

    /// Reads every accessor once: the handle is backed by Rust and is not kept beyond this call.
    static func makeLoginMethods(
        from details: HomeserverLoginDetails
    ) -> HomeserverLoginMethods {
    
        HomeserverLoginMethods(
            url               : details.url(),
            supportsPassword  : details.supportsPasswordLogin(),
            supportsOAuth     : details.supportsOauthLogin(),
            supportsSSO       : details.supportsSsoLogin(),
            slidingSyncVersion: makeSlidingSyncSupport(
                from: details.slidingSyncVersion()
            )
        )
        
    }

    /// Maps the SDK enum onto ours, where `.none` reads as "Swix cannot work here".
    static func makeSlidingSyncSupport(
        from version: SlidingSyncVersion
    ) -> SlidingSyncSupport {
    
        switch version {
            case .native: .native
            case .none  : .unsupported
        }
        
    }
}
