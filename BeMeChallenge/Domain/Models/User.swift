//
//  User.swift
//  BeMeChallenge
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

public struct User: Identifiable, Codable {
    // 필수
    @DocumentID public var id: String?
    public let nickname: String

    // 선택(Nullable) 필드 – @ExplicitNull 로 NSNull 크래시 방지
    @ExplicitNull public var bio: String?
    @ExplicitNull public var location: String?
    @ExplicitNull public var profileImageURL: String?
    @ExplicitNull public var profileImageUpdatedAt: TimeInterval?
    @ExplicitNull public var fcmToken: String?

    // ------------------------------------------------------------------
    // 1) DocumentSnapshot → User
    // ------------------------------------------------------------------
    public init?(document: DocumentSnapshot) {
        guard let d = document.data(),
              let nickname = d["nickname"] as? String else { return nil }

        self.id = document.documentID
        self.nickname = nickname
        self._bio = .init(wrappedValue: d["bio"] as? String)
        self._location = .init(wrappedValue: d["location"] as? String)
        self._profileImageURL = .init(wrappedValue: d["profileImageURL"] as? String)
        if let ts = d["profileImageUpdatedAt"] as? Timestamp {
            self._profileImageUpdatedAt = .init(wrappedValue: ts.dateValue().timeIntervalSince1970)
        } else {
            self._profileImageUpdatedAt = .init(wrappedValue: nil)
        }
        self._fcmToken = .init(wrappedValue: d["fcmToken"] as? String)
    }

    // ------------------------------------------------------------------
    // 2) QueryDocumentSnapshot → User
    // ------------------------------------------------------------------
    public init?(document: QueryDocumentSnapshot) {
        let d = document.data()
        guard let nickname = d["nickname"] as? String else { return nil }

        self.id = document.documentID
        self.nickname = nickname
        self._bio = .init(wrappedValue: d["bio"] as? String)
        self._location = .init(wrappedValue: d["location"] as? String)
        self._profileImageURL = .init(wrappedValue: d["profileImageURL"] as? String)
        if let ts = d["profileImageUpdatedAt"] as? Timestamp {
            self._profileImageUpdatedAt = .init(wrappedValue: ts.dateValue().timeIntervalSince1970)
        } else {
            self._profileImageUpdatedAt = .init(wrappedValue: nil)
        }
        self._fcmToken = .init(wrappedValue: d["fcmToken"] as? String)
    }

    // ------------------------------------------------------------------
    // 3) 직접 생성용 멤버와이즈 이니셜라이저
    // ------------------------------------------------------------------
    public init(id: String,
                nickname: String,
                bio: String? = nil,
                location: String? = nil,
                profileImageURL: String? = nil,
                profileImageUpdatedAt: TimeInterval? = nil,
                fcmToken: String? = nil) {

        self.id = id
        self.nickname = nickname
        self._bio = .init(wrappedValue: bio)
        self._location = .init(wrappedValue: location)
        self._profileImageURL = .init(wrappedValue: profileImageURL)
        self._profileImageUpdatedAt = .init(wrappedValue: profileImageUpdatedAt)
        self._fcmToken = .init(wrappedValue: fcmToken)
    }

    // 캐시-버스터 쿼리를 붙인 이미지 URL
    public var effectiveProfileImageURL: URL? {
        guard let base = profileImageURL else { return nil }
        if let v = profileImageUpdatedAt {
            let sep = base.contains("?") ? "&" : "?"
            return URL(string: "\(base)\(sep)v=\(Int(v))")
        }
        return URL(string: base)
    }
}

// ----------------------------------------------------------------------
// FirebaseAuth.User → User (임시 변환용)
// ----------------------------------------------------------------------
extension User {
    init(from fb: FirebaseAuth.User) {
        self.id = fb.uid
        self.nickname = fb.displayName ?? "User"
        self._bio = .init(wrappedValue: nil)
        self._location = .init(wrappedValue: nil)
        self._profileImageURL = .init(wrappedValue: fb.photoURL?.absoluteString)
        self._profileImageUpdatedAt = .init(wrappedValue: nil)
        self._fcmToken = .init(wrappedValue: nil)
    }
}
