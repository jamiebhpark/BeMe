// ReactionService.swift
import Foundation
import FirebaseFirestore

class ReactionService {
    static let shared = ReactionService()
    private let db = Firestore.firestore()
    
    func updateReaction(
      forPost postId: String,
      reactionType: String,
      userId: String,
      completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let postRef = db.collection("challengePosts").document(postId)
        db.runTransaction({ txn, errorPointer in
            let snap: DocumentSnapshot
            do {
                snap = try txn.getDocument(postRef)
            } catch let err as NSError {
                errorPointer?.pointee = err
                return nil
            }
            let key = reactionType
            let userField = "reactionUsers.\(key).\(userId)"
            let hasLiked = (snap.get(userField) as? Bool) ?? false
            let delta: Int64 = hasLiked ? -1 : 1

            // ✅ 한 번의 updateData 호출로 두 필드 모두 변경
            txn.updateData([
              userField:                 hasLiked ? FieldValue.delete() : true,
              "reactions.\(key)":        FieldValue.increment(delta)
            ], forDocument: postRef)

            return nil
        }, completion: { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                AnalyticsManager.shared.logReactionClick(
                  challengeId: postId,
                  reactionType: reactionType
                )
                completion(.success(()))
            }
        })
    }
}
