//
//  SplashView.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//

import SwiftUI

struct SplashView: View {

    var body: some View {

        logo
            .frame(width: 96, height: 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))

    }

    /// The real app icon when one has been added to the catalog, and a drawn stand in with the
    /// logo gradient until then. Icon sets live outside the image namespace, so only UIKit can
    /// load them, and an empty set loads as nil.
    @ViewBuilder
    private var logo: some View {

        if let icon = UIImage(named: "AppIcon") {

            Image(uiImage: icon)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 22, style: .continuous))

        } else {

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors    : [
                            Color(red: 0.09, green: 0.90, blue: 0.84),
                            Color(red: 0.0,  green: 0.655, blue: 0.612)
                        ],
                        startPoint: UnitPoint(x: 0.33, y: 0.03),
                        endPoint  : UnitPoint(x: 0.67, y: 0.97)
                    )
                )
                .overlay(alignment: .center) {
                    
                    Image(systemName: "swift")
                        .font(.system(size: 37))
                        .foregroundStyle(.black)
                    
                }

        }
    }
}
