//
//  Presentation/Home/LoginView.swift
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    private var gradient: LinearGradient {
        LinearGradient(colors: [Color("PrimaryGradientStart"), Color("PrimaryGradientEnd")],
                       startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        VStack(spacing: 28) {

            Text("BeMe Challenge")
                .font(.largeTitle.bold())
                .foregroundColor(Color("TextPrimary"))

            // ─── Google 로그인 ───
            Button {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC     = windowScene.windows.first?.rootViewController {
                    authViewModel.loginWithGoogle(using: rootVC)
                }
            } label: {
                Text("Google 로그인")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(gradient)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }

            // ─── Apple 로그인 ───
            SignInWithAppleButton(
                onRequest: { req in
                    req.requestedScopes = [.fullName, .email]
                    AuthService.shared.handleAppleSignInRequest(req)
                },
                onCompletion: { result in
                    if case .success(let authResults) = result,
                       let cred = authResults.credential as? ASAuthorizationAppleIDCredential {
                        authViewModel.loginWithApple(using: cred)
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)
        }
        .padding()
        .background(Color("BackgroundPrimary").ignoresSafeArea())
    }
}
