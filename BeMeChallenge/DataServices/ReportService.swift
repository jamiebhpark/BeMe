// ReportService.swift
import Foundation
import FirebaseFirestore

class ReportService {
    static let shared = ReportService()
    private let db = Firestore.firestore()
    
    /// 지정된 게시물(postId)에 대해 신고(reported true) 처리
    func reportPost(postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let postRef = db.collection("challengePosts").document(postId)
        postRef.updateData(["reported": true]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // 신고 이벤트 로깅
                AnalyticsManager.shared.logEvent("post_reported", parameters: ["postId": postId])
                completion(.success(()))
            }
        }
    }
}
