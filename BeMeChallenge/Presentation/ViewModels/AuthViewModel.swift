//
//  AuthViewModel.swift
//  BeMeChallenge
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

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                let loggedIn = (user != nil)
                self?.isLoggedIn = loggedIn

                if loggedIn {
                    NotificationCenter.default.post(name: .didSignIn, object: nil)
                } else {
                    // 로그아웃 시 차단 목록 초기화
                    BlockManager.shared.clearBlockedUsers()
                    NotificationCenter.default.post(name: .didSignOut, object: nil)
                }
            }
        }
    }
    deinit {
        if let h = authHandle {
            Auth.auth().removeStateDidChangeListener(h)
        }
    }

    // MARK: - Google 로그인
    func loginWithGoogle(using presentingVC: UIViewController) {
        AuthService.shared.signInWithGoogle(presenting: presentingVC) { result in
            switch result {
            case .success:
                AnalyticsManager.shared.logUserLogin(method: "google", success: true)
            case .failure(let err):
                AnalyticsManager.shared.logUserLogin(method: "google", success: false)
                print("Google 로그인 실패:", err.localizedDescription)
            }
        }
    }

    // MARK: - Apple 로그인
    func loginWithApple(using credential: ASAuthorizationAppleIDCredential) {
        AuthService.shared.signInWithApple(credential: credential) { result in
            switch result {
            case .success:
                AnalyticsManager.shared.logUserLogin(method: "apple", success: true)
            case .failure(let err):
                AnalyticsManager.shared.logUserLogin(method: "apple", success: false)
                print("Apple 로그인 실패:", err.localizedDescription)
            }
        }
    }

    // MARK: - 강제 새로고침
    func checkLoginStatus() {
        Auth.auth().currentUser?.reload { [weak self] err in
            Task { @MainActor in
                if let err { print("사용자 재로딩 실패:", err.localizedDescription) }
                let loggedIn = (Auth.auth().currentUser != nil)
                self?.isLoggedIn = loggedIn

                if !loggedIn {
                    // 이 경로로도 로그아웃 처리 시 차단 목록 초기화
                    BlockManager.shared.clearBlockedUsers()
                    NotificationCenter.default.post(name: .didSignOut, object: nil)
                }
            }
        }
    }

    // MARK: - 로그아웃
    func signOut(completion: ((Result<Void, Error>) -> Void)? = nil) {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
            // 로그아웃 직후 차단 목록 초기화
            BlockManager.shared.clearBlockedUsers()
            NotificationCenter.default.post(name: .didSignOut, object: nil)
            completion?(.success(()))
        } catch {
            print("로그아웃 에러:", error.localizedDescription)
            completion?(.failure(error))
        }
    }
}
