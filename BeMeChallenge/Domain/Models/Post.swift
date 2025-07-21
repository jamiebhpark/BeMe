//
//  Post.swift
//

import Foundation
import FirebaseFirestore

/// challengePosts/{postId}
struct Post: Identifiable, Hashable, Codable {

    // MARK: Stored
    let id            : String
    let challengeId   : String
    let userId        : String
    let imageUrl      : String
    let createdAt     : Date
    let reactions     : [String:Int]
    let reported      : Bool
    let rejected      : Bool?          // nil = 대기, false = 통과, true = 차단
    let caption       : String?
    let commentsCount : Int
    let streakNum     : Int?
    let openCountNum  : Int?

    // MARK: Firestore → Post (QueryDocumentSnapshot 전용)
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

        id            = document.documentID
        challengeId   = cid
        userId        = uid
        imageUrl      = url
        createdAt     = ts.dateValue()
        reactions     = reac
        reported      = rep
        rejected      = d["rejected"]      as? Bool
        caption       = d["caption"]       as? String
        commentsCount = d["commentsCount"] as? Int ?? 0
        streakNum     = d["streakNum"]     as? Int
        openCountNum  = d["openCountNum"]  as? Int
    }

    // MARK: Firestore → Post (DocumentSnapshot 전용)
    init?(snapshot: DocumentSnapshot) {
        guard let d = snapshot.data() else { return nil }
        guard
            let cid  = d["challengeId"] as? String,
            let uid  = d["userId"]      as? String,
            let url  = d["imageUrl"]    as? String,
            let ts   = d["createdAt"]   as? Timestamp,
            let reac = d["reactions"]   as? [String:Int],
            let rep  = d["reported"]    as? Bool
        else { return nil }

        id            = snapshot.documentID
        challengeId   = cid
        userId        = uid
        imageUrl      = url
        createdAt     = ts.dateValue()
        reactions     = reac
        reported      = rep
        rejected      = d["rejected"]      as? Bool
        caption       = d["caption"]       as? String
        commentsCount = d["commentsCount"] as? Int ?? 0
        streakNum     = d["streakNum"]     as? Int
        openCountNum  = d["openCountNum"]  as? Int
    }

    // MARK: Manual init (Preview / 테스트용)
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
        openCountNum: Int? = nil
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

// MARK: – Shallow copy helpers
extension Post {
    func copy(
        withReactions r: [String:Int]? = nil,
        caption: String? = nil,
        streakNum: Int? = nil,
        openCountNum: Int? = nil,
        commentsCount: Int? = nil
    ) -> Post {
        Post(
            id: id,
            challengeId: challengeId,
            userId: userId,
            imageUrl: imageUrl,
            createdAt: createdAt,
            reactions: r ?? reactions,
            reported: reported,
            rejected: rejected,
            caption: caption ?? self.caption,
            commentsCount: commentsCount ?? self.commentsCount,
            streakNum: streakNum ?? self.streakNum,
            openCountNum: openCountNum ?? self.openCountNum
        )
    }
}
