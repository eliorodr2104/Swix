//
//  OnboardingView.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//

import SwiftUI

struct OnboardingView: View {
    
    
    
    var body: some View {
        
        VStack(alignment: .leading) {
            
            VStack(
                alignment: .leading,
                spacing  : 8
            ) {
                
                Text("Swix")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .fontDesign(.default)
                
                Text("Private message, you select your privacy")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 52)
            
            Spacer()
            
            FederationPulseView()

            Text("Private conversations, on a network no one owns.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            
            Spacer()
            
            VStack(spacing: 8) {
                NavigationLink(value: LoginState.qrScaning) {
                    Spacer()
                    
                    HStack(spacing: 7) {
                        Image(systemName: "qrcode")
                        Text("Scan QR-Code")
                    }
                    
                    Spacer()
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)
                            
                NavigationLink(value: LoginState.chooseServer) {
                    Spacer()
                   
                    Text("Next")
                    
                    Spacer()
                }
                .buttonStyle(.glassProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}
