//
//  CircleCheckToggleStyle.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//

import SwiftUI


struct CircleCheckToggleStyle: ToggleStyle {

    var diameter: CGFloat = 26

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(
                .snappy(duration: 0.22)
            ) { configuration.isOn.toggle() }
            
        } label: {
            HStack(spacing: 12) {
                
                ZStack {
                    Circle()
                        .strokeBorder(
                            configuration.isOn ?
                                Color.accentColor : Color(.tertiaryLabel),
                            lineWidth: 1.8
                        )
                    
                    Circle()
                        .fill(Color.accentColor)
                        .scaleEffect(configuration.isOn ? 1 : 0.001)
                    
                    Image(systemName: "checkmark")
                        .font(
                            .system(
                                size  : diameter * 0.42,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.black.opacity(0.75))
                        .scaleEffect(configuration.isOn ? 1 : 0.001)
                        .opacity(configuration.isOn ? 1 : 0)
                }
                .frame(width: diameter, height: diameter)

//                configuration.label
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}
