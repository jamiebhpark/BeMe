//
//  Comment.swift
//  BeMeChallenge
//
//  Updated: 2025-07-23
//  ─────────────────────────────────────────────
//  • isAdmin Bool 추가       – 관리자 삭제 메뉴 표시용
//  • copy(isAdmin:) 헬퍼 추가
//

import Foundation
import FirebaseFirestore

/// challengePosts/{postId}/comments/{commentId}
struct Comment: Identifiable, Hashable, Codable {

    // MARK: Stored
    let id:        String          // commentId
    let userId:    String
    let text:      String
    let createdAt: Date
    let editedAt:  Date?
    let reported:  Bool

    /// ✅ 현재 **보는 사람**이 관리자라면 true
    ///    (Firestore에는 저장되지 않음)
    var isAdmin: Bool = false

    // MARK: Firestore → Comment
    init?(document: QueryDocumentSnapshot) {
        let d = document.data()
        guard
            let uid  = d["userId"]    as? String,
            let body = d["text"]      as? String,
            let ts   = d["createdAt"] as? Timestamp,
            let rep  = d["reported"]  as? Bool
        else { return nil }

        self.id        = document.documentID
        self.userId    = uid
        self.text      = body
        self.createdAt = ts.dateValue()
        self.editedAt  = (d["editedAt"] as? Timestamp)?.dateValue()
        self.reported  = rep
    }

    // Manual init (preview용)
    init(
        id: String = UUID().uuidString,
        userId: String,
        text: String,
        createdAt: Date = Date(),
        editedAt: Date? = nil,
        reported: Bool = false,
        isAdmin: Bool = false
    ) {
        self.id        = id
        self.userId    = userId
        self.text      = text
        self.createdAt = createdAt
        self.editedAt  = editedAt
        self.reported  = reported
        self.isAdmin   = isAdmin
    }

    // MARK: Helper – admin 플래그만 바꾼 복사본
    func copy(isAdmin flag: Bool) -> Comment {
        var c = self
        c.isAdmin = flag
        return c
    }
}
