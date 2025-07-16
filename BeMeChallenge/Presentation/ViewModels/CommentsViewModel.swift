//
//  CommentsViewModel.swift
//  BeMeChallenge
//
//  v7 – 추가/삭제 시 commentCountChanged(±1) 브로드캐스트
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import Combine

// MARK: - Notification keys
extension Notification.Name {
    static let commentAdded = Notification.Name("commentAdded")
    /// 피드의 말풍선 숫자 동기화용 (userInfo: ["postId": String, "delta": Int])
    static let commentCountChanged = Notification.Name("commentCountChanged")
}

@MainActor
final class CommentsViewModel: ObservableObject {

    // ───────── OUTPUT ─────────
    @Published private(set) var comments:  [Comment]    = []
    @Published private(set) var isSending = false
    @Published private(set) var userCache: [String: LiteUser] = [:]

    // ───────── PRIVATE ─────────
    private let postId: String
    private let db     = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    private let userRepo: UserRepositoryProtocol = UserRepository()

    // MARK: Init / Deinit
    init(postId: String) {
        self.postId = postId
        startListener()
    }
    deinit { listener?.remove() }

    // MARK: – Add Comment
    func addComment(text: String) {
        guard !isSending, Auth.auth().currentUser != nil else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 300 else { return }

        // 🛑 금칙어
        if hasBadWords(trimmed) {
            ModalCoordinator.shared?.showToast(.init(message: "부적절한 표현입니다"))
            return
        }

        isSending = true
        let fn = Functions.functions(region: "asia-northeast3")
            .httpsCallable("createComment")

        Task.detached { [weak self] in
            defer { Task { @MainActor in self?.isSending = false } }
            guard let self else { return }

            do {
                _ = try await fn.call([
                    "postId"   : self.postId,
                    "commentId": UUID().uuidString,
                    "text"     : trimmed,
                ])

                // 🔔 피드 말풍선 숫자 +1
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .commentCountChanged,
                        object: nil,
                        userInfo: ["postId": self.postId, "delta": 1]
                    )
                }
            } catch {
                await MainActor.run {
                    ModalCoordinator.shared?.showToast(.init(message: "업로드 실패"))
                }
            }
        }
    }

    // MARK: – Edit Comment
    func edit(_ comment: Comment, newText: String) {
        guard comment.userId == Auth.auth().currentUser?.uid else { return }

        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 300 else { return }

        if hasBadWords(trimmed) {
            ModalCoordinator.shared?.showToast(.init(message: "부적절한 표현입니다"))
            return
        }

        db.collection("challengePosts")
          .document(postId)
          .collection("comments")
          .document(comment.id)
          .updateData([
              "text"    : trimmed,
              "editedAt": FieldValue.serverTimestamp()
          ]) { err in
              if let err {
                  ModalCoordinator.shared?.showToast(.init(message: err.localizedDescription))
              }
          }
    }

    // MARK: – Delete Comment
    func delete(_ comment: Comment) {
        guard comment.userId == Auth.auth().currentUser?.uid else { return }

        db.collection("challengePosts")
          .document(postId)
          .collection("comments")
          .document(comment.id)
          .delete { err in
              if let err {
                  ModalCoordinator.shared?.showToast(.init(message: err.localizedDescription))
              } else {
                  // 🔔 말풍선 숫자 -1
                  NotificationCenter.default.post(
                      name: .commentCountChanged,
                      object: nil,
                      userInfo: ["postId": self.postId, "delta": -1]
                  )
              }
          }
    }

    // MARK: – Report Comment
    func report(_ comment: Comment) {
        let fn = Functions.functions(region: "asia-northeast3")
            .httpsCallable("reportComment")

        Task {
            do {
                _ = try await fn.call([
                    "postId"   : postId,
                    "commentId": comment.id,
                ])
                ModalCoordinator.shared?.showToast(.init(message: "신고 완료"))
            } catch {
                ModalCoordinator.shared?.showToast(.init(message: "이미 신고했거나 오류"))
            }
        }
    }

    // MARK: – Realtime Listener
    private func startListener() {
        listener = db.collection("challengePosts")
            .document(postId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let raws     = snap?.documents.compactMap(Comment.init) ?? []
                let blocked  = BlockManager.shared.blockedUserIds
                self.comments = raws.filter { !blocked.contains($0.userId) }
                self.prefetchAuthors(from: self.comments)
            }
    }

    // MARK: – Author Prefetch
    private func prefetchAuthors(from list: [Comment]) {
        let missing = Set(list.map(\.userId)).subtracting(userCache.keys)
        guard !missing.isEmpty else { return }

        userRepo.fetchUsers(withIds: Array(missing)) { [weak self] res in
            if case .success(let users) = res {
                users.forEach {
                    self?.userCache[$0.id] = LiteUser(
                        id: $0.id,
                        nickname: $0.nickname,
                        avatarURL: $0.effectiveProfileImageURL
                    )
                }
            }
        }
    }
}

/* ───────────── 간단 profanity 필터 ───────────── */
private func hasBadWords(_ text: String) -> Bool {
    let pattern = "(시\\s*발|씨\\s*발|ㅅ\\s*ㅂ|좆|존나|f+u+c*k+|s+h+i+t+|b+i+t+c+h+)"
    return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}
