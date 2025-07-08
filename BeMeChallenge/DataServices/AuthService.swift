//
//  AuthService.swift
//  BeMeChallenge
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import GoogleSignIn
import AuthenticationServices
import SwiftUI
import FirebaseCore
import CryptoKit

/// 로그인·재인증·스켈레톤 프로필 생성 담당
final class AuthService: NSObject, ObservableObject {

    // MARK: – Singleton
    static let shared = AuthService()

    // =====================================================================
    // MARK: Google Sign-In
    // =====================================================================
    func signInWithGoogle(
        presenting: UIViewController,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(.failure(simpleErr("Missing clientID"))); return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        Task { @MainActor in
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: presenting, hint: nil, additionalScopes: [])

                guard
                    let idToken   = result.user.idToken?.tokenString,
                    !idToken.isEmpty,
                    !result.user.accessToken.tokenString.isEmpty
                else { throw simpleErr("Google token missing") }

                let credential = GoogleAuthProvider.credential(
                    withIDToken:  idToken,
                    accessToken:  result.user.accessToken.tokenString)

                Auth.auth().signIn(with: credential) { [weak self] res, err in
                    guard let self else { return }

                    if let err { completion(.failure(err)); return }
                    guard let fbUser = res?.user else {
                        completion(.failure(self.simpleErr("Firebase user nil"))); return
                    }

                    self.ensureUserDoc(
                        uid: fbUser.uid,
                        defaultNickname: fbUser.displayName ?? "익명"
                    ) { ok in
                        if ok {
                            PushNotificationManager.shared.syncFcmTokenIfNeeded()
                        }
                        completion(.success(User(from: fbUser)))
                    }
                }
            } catch { completion(.failure(error)) }
        }
    }

    // =====================================================================
    // MARK: Apple Sign-In
    // =====================================================================
    private var currentNonce: String?

    func handleAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(randomNonce())
    }

    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        guard
            let nonce      = currentNonce,
            let tokenData  = credential.identityToken,
            let idToken    = String(data: tokenData, encoding: .utf8)
        else {
            completion(.failure(simpleErr("Apple ID token missing"))); return
        }

        let firebaseCred = OAuthProvider.credential(
            providerID: .apple,
            idToken:    idToken,
            rawNonce:   nonce
        )

        Auth.auth().signIn(with: firebaseCred) { [weak self] res, err in
            guard let self else { return }

            if let err { completion(.failure(err)); return }
            guard let fbUser = res?.user else {
                completion(.failure(self.simpleErr("Firebase user nil"))); return
            }

            let fallbackName = credential.fullName?.givenName ?? "익명"
            self.ensureUserDoc(
                uid: fbUser.uid,
                defaultNickname: fallbackName
            ) { ok in
                if ok {
                    PushNotificationManager.shared.syncFcmTokenIfNeeded()
                }
                completion(.success(User(from: fbUser)))
            }
        }
    }

    // =====================================================================
    // MARK: Skeleton 프로필 생성
    // =====================================================================
    /// users/{uid} 문서에 `nickname` 필드가 없으면 기본 닉네임으로 생성
    /// - Parameter completion: `true` = 성공 / 이미 존재, `false` = 쓰기 실패
    private func ensureUserDoc(
        uid: String,
        defaultNickname: String,
        completion: @escaping (Bool) -> Void          // ✅ Bool 결과
    ) {
        let ref = Firestore.firestore().collection("users").document(uid)

        ref.getDocument { snap, _ in
            if let data = snap?.data(), data["nickname"] != nil {
                completion(true)                       // 이미 존재
                return
            }

            ref.setData(["nickname": defaultNickname], merge: true) { err in
                if let err {
                    print("⚠️ ensureUserDoc failed:", err.localizedDescription)
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    // =====================================================================
    // MARK: 재인증 (Google / Apple) – 변경 없음
    // =====================================================================
    func reauthenticateWithGoogle(
        presenting: UIViewController,
        completion: @escaping (Result<AuthCredential, Error>) -> Void
    ) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(.failure(simpleErr("Missing clientID"))); return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        Task { @MainActor in
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: presenting, hint: nil, additionalScopes: [])

                guard
                    let idToken = result.user.idToken?.tokenString,
                    !idToken.isEmpty,
                    !result.user.accessToken.tokenString.isEmpty
                else { throw simpleErr("Google token missing") }

                let cred = GoogleAuthProvider.credential(
                    withIDToken:  idToken,
                    accessToken:  result.user.accessToken.tokenString
                )
                completion(.success(cred))
            } catch { completion(.failure(error)) }
        }
    }

    func reauthenticateWithApple(
        credential: ASAuthorizationAppleIDCredential,
        completion: @escaping (Result<AuthCredential, Error>) -> Void
    ) {
        guard let nonce = currentNonce else {
            completion(.failure(simpleErr("Invalid state: nonce nil"))); return
        }
        guard
            let tokenData = credential.identityToken,
            let idToken   = String(data: tokenData, encoding: .utf8)
        else {
            completion(.failure(simpleErr("Unable to fetch identity token"))); return
        }

        let cred = OAuthProvider.credential(
            providerID: .apple,
            idToken:    idToken,
            rawNonce:   nonce
        )
        completion(.success(cred))
    }

    // =====================================================================
    // MARK: Sign Out – 변경 없음
    // =====================================================================
    func signOut(completion: (Result<Void, Error>) -> Void) {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            completion(.success(()))
        } catch { completion(.failure(error)) }
    }

    // =====================================================================
    // MARK: Helper – Nonce & SHA-256
    // =====================================================================
    private func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        currentNonce = String((0..<length).compactMap { _ in chars.randomElement() })
        return currentNonce!
    }
    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
              .map { String(format: "%02x", $0) }
              .joined()
    }

    // MARK: – NSError Helper
    private func simpleErr(_ msg: String) -> NSError {
        .init(domain: "AuthService",
              code: -1,
              userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
