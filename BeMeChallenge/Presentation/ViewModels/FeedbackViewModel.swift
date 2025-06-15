// FeedbackViewModel.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth

class FeedbackViewModel: ObservableObject {
    @Published var message: String = ""
    @Published var errorMessage: String?
    @Published var isSubmitted: Bool = false
    
    private let db = Firestore.firestore()
    
    /// 사용자가 작성한 피드백 메시지를 Firestore에 제출합니다.
    func submitFeedback(completion: @escaping (Bool) -> Void) {
        // 피드백 내용이 비어있지 않은지 확인
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            self.errorMessage = "피드백 메시지를 입력해주세요."
            completion(false)
            return
        }
        
        let feedbackData: [String: Any] = [
            "userId": Auth.auth().currentUser?.uid ?? "anonymous",
            "message": trimmedMessage,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("feedback").addDocument(data: feedbackData) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                } else {
                    self.isSubmitted = true
                    completion(true)
                }
            }
        }
    }
}
