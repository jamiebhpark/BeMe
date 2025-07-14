//
//  Post.swift
//

import Foundation
import FirebaseFirestore

/// Firestore → 챌린지 포스트 모델
struct Post: Identifiable, Hashable, Codable {

    // MARK: Stored properties
    let id:            String
    let challengeId:   String
    let userId:        String
    let imageUrl:      String
    let createdAt:     Date
    let reactions:     [String:Int]
    let reported:      Bool
    let rejected:      Bool?          // nil = 대기, false = 통과, true = 차단
    let caption:       String?
    let commentsCount: Int
    let streakNum:     Int?           // 🔥 필수 챌린지 연속
    let openCountNum:  Int?           // 🏅 오픈 챌린지 누적  ← NEW

    // MARK: Firestore → Post
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

        self.id            = document.documentID
        self.challengeId   = cid
        self.userId        = uid
        self.imageUrl      = url
        self.createdAt     = ts.dateValue()
        self.reactions     = reac
        self.reported      = rep
        self.rejected      = d["rejected"]      as? Bool
        self.caption       = d["caption"]       as? String
        self.commentsCount = d["commentsCount"] as? Int ?? 0
        self.streakNum     = d["streakNum"]     as? Int
        self.openCountNum  = d["openCountNum"]  as? Int          // ← 추가
    }

    // MARK: Manual init (예: 프리뷰)
    init(
        id: String = UUID().uuidString,
        challengeId: String,
        userId: String,
        imageUrl: String,
        createdAt: Date = Date(),
        reactions: [String:Int] = [:],
        reported: Bool = false,
        rejected: Bool? = nil,
        caption: String? = nil,
        commentsCount: Int = 0,
        streakNum: Int? = nil,
        openCountNum: Int? = nil         // ← 추가
    ) {
        self.id            = id
        self.challengeId   = challengeId
        self.userId        = userId
        self.imageUrl      = imageUrl
        self.createdAt     = createdAt
        self.reactions     = reactions
        self.reported      = reported
        self.rejected      = rejected
        self.caption       = caption
        self.commentsCount = commentsCount
        self.streakNum     = streakNum
        self.openCountNum  = openCountNum
    }
}

// MARK: - Helper copy
extension Post {
    func copy(withReactions r: [String:Int]? = nil,
              streakNum: Int? = nil,
              openCountNum: Int? = nil,
              commentsCount: Int? = nil) -> Post {
        Post(
            id: id,
            challengeId: challengeId,
            userId: userId,
            imageUrl: imageUrl,
            createdAt: createdAt,
            reactions: r ?? reactions,
            reported: reported,
            rejected: rejected,
            caption: caption,
            commentsCount: commentsCount ?? self.commentsCount,
            streakNum: streakNum ?? self.streakNum,
            openCountNum: openCountNum ?? self.openCountNum      // ← 추가
        )
    }
}
