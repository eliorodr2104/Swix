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
            
            if loginViewModel?.loginMethods?.supportsPassword == true {
                VStack {
                    
                    TextField(
                        "Username",
                        text: Binding(
                            get: { loginViewModel?.username ?? "" },
                            set: { loginViewModel?.username = $0  }
                        )
                    )
                    .textFieldStyle(.plain)
                    
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
                    
                }
                .padding()
                .surface(
                    .ultraThinMaterial,
                    in: .roundedRect(cornerRadius: 15)
                )
                .clipped()
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
                
                Image(systemName: "")
                
                Text("Continue in browser")
                
                Spacer()
                
            }
            .buttonStyle(.bordered)
            .disabled(loginViewModel?.isLoading == true)
                        
            Spacer()
            
            if loginViewModel?.loginMethods?.supportsPassword == true {
                // username + password -> await loginViewModel?.loginTapped()
            }

            if loginViewModel?.loginMethods?.supportsOAuth == true {
                // browser -> await loginViewModel?.oauthTapped()
            }
            
            Button {  } label: {
                Spacer()
                
                Text("Validate")
                
                Spacer()
            }
            .buttonStyle(.glassProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}
