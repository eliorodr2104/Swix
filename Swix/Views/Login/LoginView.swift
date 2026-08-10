//
//  LoginView.swift
//  Swix
//
//  Created by Eliomar on 10/08/2026.
//

import SwiftUI
import SwiftUIKit

struct LoginView: View {
    
    @Environment(\.loginViewModel)
    private var loginViewModel
    
    /// The two fields the keyboard can serve, so the return key can hand focus down the form.
    private enum Field {

        case username
        case password
    }

    @FocusState
    private var focusedField: Field?
    
    @State
    private var errorLoginMessage: String?
    
    @State
    private var haptics = HapticsPlayer()
    
    var body: some View {
        
        VStack(
            alignment: .leading,
            spacing  : 17
        ) {
            
            VStack(
                alignment: .leading,
                spacing  : 5
            ) {
                
                Text("Login")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .fontDesign(.default)
                
                let serverName = Text(loginViewModel!.homeserverText)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("With your account on \(serverName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
            }
            
            VStack(spacing: 8) {
                VStack {
                    
                    TextField(
                        "Username",
                        text: Binding(
                            get: { loginViewModel?.username ?? "" },
                            set: { loginViewModel?.username = $0  }
                        )
                    )
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                    Divider()
                        .padding(.vertical, 6)

                    SecureField(
                        "Password",
                        text: Binding(
                            get: { loginViewModel?.password ?? "" },
                            set: { loginViewModel?.password = $0  }
                        )
                    )
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .onSubmit { submitLogin() }

                }
                .loadingPlaceholder(
                    loginViewModel?.isLoading == true
                ) {
                    if loginViewModel?.loginMethods?.supportsPassword == true {
                        focusedField = .username
                    }
                }
                .padding()
                .surface(
                    .ultraThinMaterial,
                    in: .roundedRect(cornerRadius: 15)
                )
                .stroke(
                    errorLoginMessage == nil ? .clear : .red,
                    in: .roundedRect(cornerRadius: 15)
                )
                .disabled(
                    loginViewModel?.isLoading == true ||
                    loginViewModel?.loginMethods?.supportsPassword == false
                )
                
                if let error = errorLoginMessage {
                    
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
            
            HStack {
                
                Rectangle()
                    .fill(.separator)
                    .frame(maxWidth: .infinity, maxHeight: 1)
                
                Text("Other")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                Rectangle()
                    .fill(.separator)
                    .frame(maxWidth: .infinity, maxHeight: 1)
                
            }
            
            Button {
                Task { await loginViewModel?.oauthTapped() }
                
            } label: {
                
                Spacer()
                
                HStack {
                    Image(systemName: "network")
                    
                    Text("Continue in browser")
                }
                .padding(.vertical, 7)
                
                Spacer()
                
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.primary)
            .disabled(
                loginViewModel?.isLoading == true ||
                loginViewModel?.loginMethods?.supportsOAuth == false
            )
                        
            Spacer()
                        
//            Button {
//                errorLoginMessage = nil
//                
//                submitLogin()
//
//            } label: {
//                Spacer()
//
//                Text("Validate")
//                    .padding(.vertical, 7)
//
//                Spacer()
//            }
//            .buttonStyle(.glassProminent)
//            .frame(maxWidth: .infinity)
//            .disabled(
//                loginViewModel?.username.isEmpty ?? true ||
//                loginViewModel?.password.isEmpty ?? true
//            )
        }
        .padding()
    }

    /// One entry point for the button and the keyboard's go key, so the two can never diverge.
    private func submitLogin() {

        guard loginViewModel?.loginMethods?.supportsPassword == true,
              loginViewModel?.username.isEmpty == false,
              loginViewModel?.password.isEmpty == false else {
            return
        }

        Task {
            await loginViewModel?.loginTapped()

            if let failure = loginViewModel?.failure {
                errorLoginMessage = failure.message
                haptics.error()
            }
        }
    }
}
