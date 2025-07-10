//
//  Comment.swift
//  BeMeChallenge
//
//  Created by ChatGPT on 2025/07/10.
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
        reported: Bool = false
    ) {
        self.id        = id
        self.userId    = userId
        self.text      = text
        self.createdAt = createdAt
        self.editedAt  = editedAt
        self.reported  = reported
    }
}
