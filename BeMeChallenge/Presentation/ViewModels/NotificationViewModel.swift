// Presentation/ViewModels/NotificationViewModel.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class NotificationViewModel: ObservableObject {
    
    @Published private(set) var state: Loadable<[AppNotification]> = .idle
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    func subscribe() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        state = .loading
        listener?.remove()
        listener = db.collection("notifications")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err { self.state = .failed(err); return }
                do {
                    let list = try snap?.documents.map {
                        try $0.data(as: AppNotification.self)
                    } ?? []
                    self.state = .loaded(list)
                } catch { self.state = .failed(error) }
            }
    }
    
    deinit { listener?.remove() }
}
