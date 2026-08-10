//
//  ScanVerdict.swift
//  Swix
//
//  Created by Eliomar on 09/08/2026.
//


/// What a content scanner concluded about one piece of media.
enum ScanVerdict: Equatable {

    /// The scanner inspected the file and found nothing dangerous.
    case clean(info: String)

    /// The scanner refused the file, either for its contents or for its mime type.
    case infected(info: String)

    /// No scanner is configured for this deployment, so nothing was inspected.
    case unavailable

    /// Whether the app may show this media.
    ///
    /// A deployment without a scanner behaves exactly as it did before scanning existed, so an
    /// absent verdict must not hide content the user is entitled to see.
    var isSafeToDisplay: Bool {
        switch self {
            case .clean, .unavailable: true
            case .infected: false
        }
    }

    /// The scanner's own explanation, absent when no scan happened.
    var info: String? {
        switch self {
            case .clean(let info), .infected(let info): info
            case .unavailable: nil
        }
    }
}
