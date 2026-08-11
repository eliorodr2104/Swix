//
//  PressableRowButtonStyle.swift
//  Swix
//
//  Created by Eliomar on 11/08/2026.
//

import SwiftUI

struct PressableRowButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {

        configuration.label
            .contentShape(.rect)
            .background(
                configuration.isPressed ?
                Color(.systemGray6) : .clear
            )
    }
}
