//Post.swift
import Foundation
import FirebaseFirestore

/// Firestore → 챌린지 포스트 모델
struct Post: Identifiable, Hashable, Codable {

    // MARK: stored properties
    let id: String                     // Firestore 문서 ID (non-optional)
    let challengeId: String
    let userId: String
    let imageUrl: String
    let createdAt: Date
    let reactions: [String:Int]
    let reported: Bool
    let caption: String?

    // MARK: Firestore → Post 초기화
    init?(document: QueryDocumentSnapshot) {
        let d = document.data()
        guard
            let cid  = d["challengeId"] as? String,
            let uid  = d["userId"]      as? String,
            let url  = d["imageUrl"]    as? String,
            let ts   = d["createdAt"]   as? Timestamp,
            let reac = d["reactions"]   as? [String:Int],
            let rep  = d["reported"]    as? Bool
        else { return nil }

        self.id          = document.documentID          // ✅ 유일 ID
        self.challengeId = cid
        self.userId      = uid
        self.imageUrl    = url
        self.createdAt   = ts.dateValue()
        self.reactions   = reac
        self.reported    = rep
        self.caption     = d["caption"] as? String
    }

    // (선택) 직접 생성용 memberwise-init
    init(id: String = UUID().uuidString,
         challengeId: String, userId: String, imageUrl: String,
         createdAt: Date = Date(),
         reactions: [String:Int] = [:],
         reported: Bool = false,
         caption: String? = nil) {

        self.id          = id
        self.challengeId = challengeId
        self.userId      = userId
        self.imageUrl    = imageUrl
        self.createdAt   = createdAt
        self.reactions   = reactions
        self.reported    = reported
        self.caption     = caption
    }
}
