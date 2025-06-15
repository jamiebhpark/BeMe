//LoginView.swift
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    // 전역에서 주입된 AuthViewModel 사용
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {

            Text("BeMe Challenge")
                .font(.largeTitle).bold()

            // ── Google 로그인
            Button {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC     = windowScene.windows.first?.rootViewController {
                    authViewModel.loginWithGoogle(using: rootVC)
                }
            } label: {
                Text("Google 로그인")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }

            // ── Apple 로그인
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                    AuthService.shared.handleAppleSignInRequest(request)
                },
                onCompletion: { result in
                    if case .success(let authResults) = result,
                       let cred = authResults.credential as? ASAuthorizationAppleIDCredential {
                        authViewModel.loginWithApple(using: cred)
                    } else if case .failure(let err) = result {
                        print("Apple 로그인 실패:", err.localizedDescription)
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(8)
        }
        .padding()
    }
}
