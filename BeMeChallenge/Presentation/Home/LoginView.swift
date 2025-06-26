//
//  Presentation/Home/LoginView.swift
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var authVM : AuthViewModel
    @Environment(\.colorScheme) private var scheme           // 💡 현재 모드
    private let borderGray = Color(UIColor.systemGray4)

    var body: some View {
        VStack(spacing: 28) {

            // MARK: ① 타이틀
            Text("BeMe")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundColor(Color("TextPrimary"))

            // MARK: ② Google 버튼
            Button {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root  = scene.windows.first?.rootViewController {
                    authVM.loginWithGoogle(using: root)
                }
            } label: {
                HStack(spacing: 12) {
                    Image("google-logo")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 24, height: 24)

                    Text("Sign in with Google")
                        .font(.system(size: 17, weight: .semibold))
                        // 다크에서는 검정 글자 · 라이트에서는 시스템 기본(검정)이므로 동일
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity, minHeight: 50)   // Apple 버튼과 동일
                .background(Color.white)                     // 항상 흰색 → 다크에서도 시인성 확보
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderGray, lineWidth: 1)
                )
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)

            // MARK: ③ Apple 버튼 (모드별 스타일)
            SignInWithAppleButton(
                onRequest: { req in
                    req.requestedScopes = [.fullName, .email]
                    AuthService.shared.handleAppleSignInRequest(req)
                },
                onCompletion: { result in
                    if case .success(let res) = result,
                       let cred = res.credential as? ASAuthorizationAppleIDCredential {
                        authVM.loginWithApple(using: cred)
                    }
                }
            )
            .signInWithAppleButtonStyle(
                scheme == .dark ? .white /* 검정 배경에서 하얀 버튼 */ : .black
            )
            .frame(height: 50)
            .cornerRadius(10)
            .padding(.horizontal, 16)
        }
        .padding()
        .background(Color("BackgroundPrimary").ignoresSafeArea())
    }
}
