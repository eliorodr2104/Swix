//
//  ChooseServerView.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//

import SwiftUI
import SwiftUIKit

struct ChooseServerView: View {
    
    @Environment(\.loginViewModel)
    private var loginViewModel
    
    @FocusState
    private var isHomemadeTextfieldFocus: Bool
    
    @State
    private var isMatrixServerSelected: Bool = false
    
    @State
    private var isHomemadeServerSelected: Bool = false
    
    @State
    private var serverURL: String = ""
    
    var body: some View {
        
        VStack(
            alignment: .leading,
            spacing  : 17
        ) {
            
            VStack(
                alignment: .leading,
                spacing  : 5
            ) {
                
                Text("Server Location")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .fontDesign(.default)
                
                Text("You can change it whenever you want.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
            }
            
            
            VStack {
                
                serverRow(
                    title   : "matrix.org",
                    subTitle: "Thoe most usage public server",
                    isOn    : $isMatrixServerSelected
                )
                
                Divider()
                    .padding(.vertical, 6)
                
                serverRow(
                    title   : "Personal Server",
                    subTitle: "Your personal server",
                    isOn    : $isHomemadeServerSelected
                )
                
            }
            .padding()
            .surface(
                .ultraThinMaterial,
                in: .roundedRect(cornerRadius: 15)
            )
            .clipped()
                    
            if isHomemadeServerSelected {

                TextField(
                    "http://matrix.yourdomain.com",
                    text: $serverURL
                )
                .focused($isHomemadeTextfieldFocus)
                .textFieldStyle(.plain)
                .transition(
                    .move(edge: .top)
                    .combined(with: .opacity)
                )
                .padding()
                .surface(
                    .ultraThinMaterial,
                    in: .roundedRect(cornerRadius: 15)
                )
                .onAppear {
                    isHomemadeTextfieldFocus = true
                }

            }

            Spacer()

            VStack(spacing: 8) {
                            
                NavigationLink(value: LoginState.signup) {
                    Spacer()
                   
                    Text("Sign Up")
                    
                    Spacer()
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)
                
                NavigationLink(value: LoginState.login) {
                    Spacer()
                    
                    HStack(spacing: 7) {
                        Text("Login")
                    }
                    
                    Spacer()
                }
                .buttonStyle(.glassProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .animation(
            .snappy(duration: 0.28),
            value: isHomemadeServerSelected
        )
        .onChange(of: isMatrixServerSelected) { _, newValue in
            if newValue && isHomemadeServerSelected {
                isHomemadeServerSelected = false
            }
        }
        .onChange(of: isHomemadeServerSelected) { _, newValue in
            if newValue && isMatrixServerSelected {
                isMatrixServerSelected = false
            }
        }
        .onDisappear {
            serverURL = isHomemadeServerSelected ? serverURL : "matrix.org"
            
            Task {
                loginViewModel?.homeserverText = serverURL
                await loginViewModel?.discover()
            }
        }
        .padding()
        
    }
    
    private func serverRow(
        title   : String,
        subTitle: String,
        isOn    : Binding<Bool>
    ) -> some View {
        
        HStack {
            
            Toggle(
                title,
                isOn: isOn
            )
            .toggleStyle(CircleCheckToggleStyle())
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(subTitle)
                    .font(.footnote)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        
    }
}
