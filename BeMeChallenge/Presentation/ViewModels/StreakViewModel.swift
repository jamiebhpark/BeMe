//
//  StreakViewModel.swift
//  BeMeChallenge
//
//  v2 – 서버 streakCount / graceLeft 읽기 전용
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class StreakViewModel: ObservableObject {

    // UI-바인딩 값 --------------------------------------------------------
    @Published var streakDays = 0          // 연속 일수
    @Published var graceLeft  = 2          // 남은 Grace Day
    @Published var errorMessage: String?   // 에러 표시(선택)

    private let db = Firestore.firestore()

    /// Firestore 의 `users/{uid}` 문서에서 Warm-Streak 필드만 읽어 온다
    func fetchAndCalculateStreak() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        Task {
            do {
                let doc = try await db.collection("users").document(uid).getDocument()

                streakDays = doc.get("streakCount") as? Int ?? 0
                graceLeft  = doc.get("graceLeft")   as? Int ?? 2
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
