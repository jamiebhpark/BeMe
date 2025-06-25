//
//  User.swift
//  BeMeChallenge
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

public struct User: Identifiable, Codable {
    // MARK: - Required
    public let id: String
    public let nickname: String

    // MARK: - Warm-Streak
    public let streakCount: Int      // 현재 연속일
    public let graceLeft:   Int      // 남은 Grace-Day(0–2)
    public let lastDate:    String   // 마지막 업로드 "YYYY-MM-DD"

    // MARK: - Optional (@ExplicitNull 로 NSNull 방지)
    public let bio: String?
    public let location: String?
    public let profileImageURL: String?
    public let profileImageUpdatedAt: TimeInterval?
    public let fcmToken: String?

    // ───────────────────────────────────────────────
    // 1) DocumentSnapshot → User (읽기 전용)
    // ───────────────────────────────────────────────
    public init?(document: DocumentSnapshot) {
        guard
            let d = document.data(),
            let nickname = d["nickname"] as? String
        else { return nil }

        self.id          = document.documentID
        self.nickname    = nickname
        self.streakCount = d["streakCount"] as? Int ?? 0
        self.graceLeft   = d["graceLeft"]   as? Int ?? 2
        self.lastDate    = d["lastDate"]    as? String ?? ""
        self.bio         = d["bio"]         as? String
        self.location    = d["location"]    as? String
        self.profileImageURL = d["profileImageURL"] as? String

        if let ts = d["profileImageUpdatedAt"] as? Timestamp {
            self.profileImageUpdatedAt = ts.dateValue().timeIntervalSince1970
        } else {
            self.profileImageUpdatedAt = nil
        }

        self.fcmToken    = d["fcmToken"]    as? String
    }

    // ───────────────────────────────────────────────
    // 2) QueryDocumentSnapshot → User (읽기 전용)
    // ───────────────────────────────────────────────
    public init?(document: QueryDocumentSnapshot) {
        let d = document.data()
        guard let nickname = d["nickname"] as? String else { return nil }

        self.id          = document.documentID
        self.nickname    = nickname
        self.streakCount = d["streakCount"] as? Int ?? 0
        self.graceLeft   = d["graceLeft"]   as? Int ?? 2
        self.lastDate    = d["lastDate"]    as? String ?? ""
        self.bio         = d["bio"]         as? String
        self.location    = d["location"]    as? String
        self.profileImageURL = d["profileImageURL"] as? String

        if let ts = d["profileImageUpdatedAt"] as? Timestamp {
            self.profileImageUpdatedAt = ts.dateValue().timeIntervalSince1970
        } else {
            self.profileImageUpdatedAt = nil
        }

        self.fcmToken    = d["fcmToken"]    as? String
    }

    // ───────────────────────────────────────────────
    // 3) Manual initializer (테스트/미리보기/쓰기)
    // ───────────────────────────────────────────────
    public init(
        id: String,
        nickname: String,
        streakCount: Int = 0,
        graceLeft: Int   = 2,
        lastDate: String = "",
        bio: String? = nil,
        location: String? = nil,
        profileImageURL: String? = nil,
        profileImageUpdatedAt: TimeInterval? = nil,
        fcmToken: String? = nil
    ) {
        self.id                   = id
        self.nickname             = nickname
        self.streakCount          = streakCount
        self.graceLeft            = graceLeft
        self.lastDate             = lastDate
        self.bio                  = bio
        self.location             = location
        self.profileImageURL      = profileImageURL
        self.profileImageUpdatedAt = profileImageUpdatedAt
        self.fcmToken             = fcmToken
    }

    // MARK: - Helpers
    /// 캐시-버스터 쿼리를 붙인 프로필 이미지 URL
    public var effectiveProfileImageURL: URL? {
        guard let base = profileImageURL else { return nil }
        if let v = profileImageUpdatedAt {
            let sep = base.contains("?") ? "&" : "?"
            return URL(string: "\(base)\(sep)v=\(Int(v))")
        }
        return URL(string: base)
    }
}

// MARK: - FirebaseAuth.User → User (임시 변환, 쓰기용)
extension User {
    init(from fb: FirebaseAuth.User) {
        self.id                   = fb.uid
        self.nickname             = fb.displayName ?? "User"
        self.streakCount          = 0
        self.graceLeft            = 2
        self.lastDate             = ""
        self.bio                  = nil
        self.location             = nil
        self.profileImageURL      = fb.photoURL?.absoluteString
        self.profileImageUpdatedAt = nil
        self.fcmToken             = nil
    }
}
