// StreakViewModel.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth

class StreakViewModel: ObservableObject {
    @Published var currentStreak: Int = 0
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()

    /// Firestore에서 사용자의 참여 날짜를 가져옵니다.
    private func fetchParticipationDates(completion: @escaping ([Date]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        db.collection("users")
          .document(uid)
          .collection("participations")
          .order(by: "date", descending: false)
          .getDocuments { snapshot, error in
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                completion([])
                return
            }
            let dates = snapshot?.documents.compactMap { doc in
                (doc.data()["date"] as? Timestamp)?.dateValue()
            } ?? []
            completion(dates)
        }
    }

    /// 연속 참여 일수를 계산합니다.
    func calculateStreak(from dates: [Date]) -> Int {
        let cal = Calendar.current
        guard !dates.isEmpty else { return 0 }

        let sorted = dates.sorted()
        var streak = 1
        var prev = sorted.last!

        for day in sorted.reversed().dropFirst() {
            let diff = cal.dateComponents([.day], from: day, to: prev).day ?? Int.max
            if diff == 0 {
                continue  // 같은 날 중복 기록 무시
            } else if diff == 1 {
                streak += 1
                prev = day
            } else {
                break
            }
        }
        return streak
    }

    /// Firestore에서 날짜를 가져와서 streak 계산 후 퍼블리시합니다.
    func fetchAndCalculateStreak() {
        fetchParticipationDates { [weak self] dates in
            guard let self = self else { return }
            let s = self.calculateStreak(from: dates)
            DispatchQueue.main.async {
                self.currentStreak = s
            }
        }
    }
}
