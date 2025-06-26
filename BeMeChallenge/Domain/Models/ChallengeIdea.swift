//
//  ChallengeIdea.swift
//  BeMeChallenge
//

import FirebaseFirestore

struct ChallengeIdea: Identifiable, Codable {
    @DocumentID var id: String?
    var title:       String
    var description: String
    var ownerId:     String
    var createdAt:   Timestamp

    // 반응
    var likeUsers: [String] = []
    var likeCount: Int      = 0

    // 삭제(아카이브) 플래그
    var isArchived: Bool    = false
}
