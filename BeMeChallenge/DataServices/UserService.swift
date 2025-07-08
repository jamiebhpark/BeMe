//
//  UserService.swift
//  BeMeChallenge
//

import Foundation
import FirebaseFirestore

/// Firestore 사용자 관련 단순 API
@MainActor
final class UserService {

    // MARK: – Singleton
    static let shared = UserService()
    private init() {}

    // MARK: – 약관·마케팅 동의 저장
    /// users/{uid} 문서에 동의 필드를 병합(merge)합니다.
    func updateConsent(uid: String,
                       eula: Bool,
                       privacy: Bool,
                       marketing: Bool) async throws {

        let data: [String: Any] = [
            "agreedEULA"    : eula,
            "agreedPrivacy" : privacy,
            "allowMarketing": marketing,
            "agreedAt"      : FieldValue.serverTimestamp()
        ]

        try await Firestore.firestore()
            .collection("users")
            .document(uid)
            .setData(data, merge: true)
    }
}
