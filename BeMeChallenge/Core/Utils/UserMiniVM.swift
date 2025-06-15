// Utils/UserMiniVM.swift
import SwiftUI
import FirebaseFirestore

@MainActor
final class UserMiniVM: ObservableObject {
    @Published var user: User?
    private let db = Firestore.firestore()

    init(userId: String) { fetch(userId) }

    private func fetch(_ uid: String) {
        db.collection("users").document(uid).getDocument { snap, _ in
            guard let d = snap?.data() else { return }
            let u = User(
                id: uid,
                nickname: d["nickname"] as? String ?? "익명",
                bio: nil,
                location: nil,
                profileImageURL: d["profileImageURL"] as? String,
                fcmToken: nil
            )
            Task { @MainActor in self.user = u }
        }
    }
}
