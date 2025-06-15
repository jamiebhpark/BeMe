// Domain/Models/DTO/NewPost.swift
import Foundation
import FirebaseFirestore

/// Firestore에 **저장할 때만** 쓰는 구조체 (DocumentID 없음)
struct NewPost: Codable {
    let challengeId: String
    let userId: String
    let imageUrl: String
    let createdAt: Timestamp
    let reactions: [String:Int]
    let reported: Bool
    let caption: String?
}
