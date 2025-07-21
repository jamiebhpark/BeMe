// ReportService.swift
import FirebaseFunctions

class ReportService {
    static let shared = ReportService()
    // ✅ 반드시 **함수 지역**을 지정해 주세요
    private let functions = Functions.functions(region: "asia-northeast3")

    /// 게시물 신고
    func reportPost(postId: String,
                    completion: @escaping (Result<Void, Error>) -> Void) {
        functions.httpsCallable("reportPost")
            .call(["postId": postId]) { _, err in
                if let err = err {
                    completion(.failure(err))
                } else {
                    AnalyticsManager.shared.logEvent(
                        "post_reported", parameters: ["postId": postId]
                    )
                    completion(.success(()))
                }
            }
    }

    /// 댓글 신고
    func reportComment(postId: String,
                       commentId: String,
                       completion: @escaping (Result<Void, Error>) -> Void) {
        functions.httpsCallable("reportComment")
            .call(["postId": postId, "commentId": commentId]) { _, err in
                err == nil ? completion(.success(()))
                           : completion(.failure(err!))
            }
    }
}
