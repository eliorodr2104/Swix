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
    private var isMatrixServerSelected: Bool = true
    
    @State
    private var isHomemadeServerSelected: Bool = false
    
    @State
    private var serverURL: String = ""
    
    @State
    private var showLogin: Bool = false
    
    @State
    private var showRegister: Bool = false
    
    @State
    private var showServerError: String? 

    @State
    private var haptics = HapticsPlayer()
    
    private var isNextButtonDisabled: Bool {
        isHomemadeServerSelected && serverURL.isEmpty
    }
    
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
                    title   : "Homeserver",
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

                VStack(spacing: 7) {
                    TextField(
                        "Server URL",
                        text: $serverURL
                    )
                    .focused($isHomemadeTextfieldFocus)
                    .textFieldStyle(.plain)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit {
                        guard !isNextButtonDisabled else {
                            return
                        }

                        nextStep($showLogin)
                    }
                    .opacity(loginViewModel?.isLoading == true ? 0 : 1)
                    .overlay(alignment: .leading) {
                        if loginViewModel?.isLoading == true {
                            CharacterBounceText(text: serverURL)
                        }
                    }
                    .disabled(loginViewModel?.isLoading == true)
                    .padding()
                    .surface(
                        .ultraThinMaterial,
                        in: .roundedRect(cornerRadius: 15)
                    )
                    .stroke(
                        showServerError == nil ? .clear : .red,
                        in: .roundedRect(cornerRadius: 15)
                    )
                    .onAppear {
                        isHomemadeTextfieldFocus = true
                    }
                    
                    if let error = showServerError {
                        
                        HStack(alignment: .top) {
                            
                            Image(systemName: "exclamationmark.circle")
                                .font(.caption)
                            
                            Text(error)
                                .font(.caption)
                                .fontWeight(.regular)
                            
                            Spacer()
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)

                    }
                }
                .clipped()
                .transition(
                    .move(edge: .top)
                    .combined(with: .opacity)
                )
                .zIndex(-1)

            }
            

            Spacer()
            

            VStack(spacing: 8) {
                            
                Button {
                    nextStep($showRegister)
                    
                } label: {
                    Spacer()
                   
                    Text("Sign Up")
                        .padding(.vertical, 7)
                    
                    Spacer()
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)
                .disabled(isNextButtonDisabled)
                
                Button {
                    nextStep($showLogin)
                    
                } label: {
                    Spacer()
                    
                    Text("Login")
                        .padding(.vertical, 7)
                    
                    Spacer()
                }
                .disabled(isNextButtonDisabled)
                .buttonStyle(.glassProminent)
                .frame(maxWidth: .infinity)
            }
            .scaleEffect(isNextButtonDisabled ? 0.97 : 1)
            .opacity(isNextButtonDisabled ? 0.85 : 1)
            .animation(
                .snappy(duration: 0.25),
                value: isNextButtonDisabled
            )
            
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

            if !newValue {
                isHomemadeTextfieldFocus = false
            }
        }
        .onChange(of: showRegister) { _, newValue in
            
            if newValue {
                showRegister = false
                
                if loginViewModel?.loginMethods?.supportsOAuth == true {
                    Task {
                        await loginViewModel?.signUpTapped()
                    }
                    
                } else {
                    haptics.error()
                    showServerError = "Server not support OAuth"
                }
            }
        }
        .navigationDestination(isPresented: $showLogin) {
            LoginView()
        }
        .padding()
        
    }
    
    
    // MARK: - Views
    
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
    
    // MARK: - Handlers
    
    private func nextStep(_ show: Binding<Bool>) {
        
        showServerError = nil
        serverURL = isHomemadeServerSelected ? serverURL : "matrix.org"
        loginViewModel?.homeserverText = serverURL

        if isHomemadeServerSelected {
            let timing = CharacterBounceText.waveTiming(for: serverURL)

            haptics.startWave(
                travel: timing.travel,
                period: timing.period
            )
        }

        Task {
            await loginViewModel?.discover()

            haptics.stopWave()

            if let failure = loginViewModel?.failure {

                haptics.error()
                showServerError = failure.title

            } else {
                haptics.success()
                show.wrappedValue = true
            }
        }
        
        if isMatrixServerSelected {
            show.wrappedValue = true
        }
        
    }
}
