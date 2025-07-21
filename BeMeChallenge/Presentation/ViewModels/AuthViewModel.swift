//
//  AuthViewModel.swift
//  BeMeChallenge
//
//  Updated: 2025-07-22
//  ─────────────────────────────────────────────
//  • @Published var isAdmin 추가
//  • 로그인 / 강제 새로고침 시 custom-claim 조회
//  • 로그아웃 시 isAdmin 리셋
//

import SwiftUI
import FirebaseAuth
import Combine
import AuthenticationServices
import GoogleSignIn

// 전역 로그인/로그아웃 브로드캐스트
extension Notification.Name {
    static let didSignIn  = Notification.Name("AuthDidSignIn")
    static let didSignOut = Notification.Name("AuthDidSignOut")
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

@MainActor
final class AuthViewModel: ObservableObject {

    // ───────── PUBLIC 상태 ─────────
    @Published var isLoggedIn = false
    @Published var isAdmin    = false          // ⭐️ 추가

    // ───────── PRIVATE ─────────
    private var authHandle : AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()

    // MARK: – Init / Deinit
    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            Task { @MainActor in
                self.isLoggedIn = (user != nil)

                if let u = user {
                    // ⚡️ custom-claim 조회
                    let tok = try? await u.getIDTokenResult()
                    self.isAdmin = (tok?.claims["isAdmin"] as? Bool) ?? false
                    NotificationCenter.default.post(name: .didSignIn, object: nil)
                } else {
                    self.isAdmin = false
                    BlockManager.shared.clearBlockedUsers()
                    NotificationCenter.default.post(name: .didSignOut, object: nil)
                }
            }
        }
    }
    deinit {
        if let h = authHandle { Auth.auth().removeStateDidChangeListener(h) }
    }

    // MARK: – Google 로그인
    func loginWithGoogle(using presentingVC: UIViewController) {
        AuthService.shared.signInWithGoogle(presenting: presentingVC) { result in
            AnalyticsManager.shared.logUserLogin(method: "google",
                                                 success: result.isSuccess)
            if case .failure(let err) = result {
                print("Google 로그인 실패:", err.localizedDescription)
            }
        }
    }

    // MARK: – Apple 로그인
    func loginWithApple(using credential: ASAuthorizationAppleIDCredential) {
        AuthService.shared.signInWithApple(credential: credential) { result in
            AnalyticsManager.shared.logUserLogin(method: "apple",
                                                 success: result.isSuccess)
            if case .failure(let err) = result {
                print("Apple 로그인 실패:", err.localizedDescription)
            }
        }
    }

    // MARK: – 강제 새로고침 (EULA 등 후처리)
    func checkLoginStatus() {
        guard let user = Auth.auth().currentUser else { return }

        user.reload { [weak self] err in
            guard let self else { return }
            Task { @MainActor in
                if let err { print("사용자 재로딩 실패:", err.localizedDescription) }

                self.isLoggedIn = true   // user 가 nil 아님 → 로그인 상태

                // ⚡️ admin 플래그 갱신
                let tok = try? await user.getIDTokenResult(forcingRefresh: true)
                self.isAdmin = (tok?.claims["isAdmin"] as? Bool) ?? false
            }
        }
    }

    // MARK: – 로그아웃
    func signOut(completion: ((Result<Void, Error>) -> Void)? = nil) {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()

            UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
            BlockManager.shared.clearBlockedUsers()

            isLoggedIn = false
            isAdmin    = false          // ⭐️ 리셋
            NotificationCenter.default.post(name: .didSignOut, object: nil)
            completion?(.success(()))
        } catch {
            print("로그아웃 에러:", error.localizedDescription)
            completion?(.failure(error))
        }
    }
}
