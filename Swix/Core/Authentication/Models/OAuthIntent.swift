//
//  OAuthIntent.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//


/// Which page the homeserver's OAuth provider should open the round trip on.
///
/// The trip itself is identical either way: browser out, callback in, a signed in session at the
/// end. The intent only decides whether the user lands on the provider's sign in form or on its
/// account creation one, which is also why Swix needs no registration screen of its own.
enum OAuthIntent {

    /// The provider greets the user with its sign in form.
    case signIn

    /// The provider greets the user with its account creation form.
    case signUp
}
