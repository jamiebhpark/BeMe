//
//  Presentation/Home/LoginView.swift
//

//
//  Presentation/Home/LoginView.swift
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.colorScheme) private var scheme
    private let borderGray = Color(UIColor.systemGray4)

    // 공통 폭 (= Apple 가이드 최소 140pt 이상)
    private let buttonWidth: CGFloat = 280

    var body: some View {
        ZStack {
            // 배경 이미지
            Image("LoginView")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // 타이틀
                Text("BeMe")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(Color("TextPrimary"))

                // 로그인 버튼 스택
                VStack(spacing: 16) {
                    googleButton
                    appleButton
                }

                Spacer(minLength: 80)   // 홈바와 적당히 간격
            }
        }
    }

    // MARK: - Google 버튼
    private var googleButton: some View {
        Button {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root  = scene.windows.first?.rootViewController else { return }
            authVM.loginWithGoogle(using: root)
        } label: {
            HStack(spacing: 12) {
                Image("google-logo")
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 24, height: 24)
                Text("Sign in with Google")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
            }
            .frame(width: buttonWidth, height: 48)          // Google 가이드: 48×44 이상
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(borderGray, lineWidth: 1))
            .cornerRadius(10)
        }
    }

    // MARK: - Apple 버튼
    private var appleButton: some View {
        SignInWithAppleButton(
            .signIn,                                       // HIG 추천 라벨
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
        .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
        .frame(width: buttonWidth, height: 44)              // Apple 가이드: ≥140×44
        .cornerRadius(10)
    }
}
