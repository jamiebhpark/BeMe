//
//  CommentsViewModel.swift
//  BeMeChallenge
//
//  Updated: 2025-07-10 – 로컬 금칙어 필터 + 실패 토스트
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import Combine

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

    // MARK: Init
    init(postId: String) {
        self.postId = postId
        startListener()
    }
    deinit { listener?.remove() }

    // MARK: – Public API
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

        let pid = self.postId                      // 캡처용
        Task.detached { [weak self] in
            defer { Task { @MainActor in self?.isSending = false } }

            do {
                _ = try await fn.call([
                    "postId":    pid,
                    "commentId": UUID().uuidString,
                    "text":      trimmed,
                ])

                // ✅ 댓글 작성 성공 → 즉시 UI 갱신용 노티
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .commentAdded,
                        object: nil,
                        userInfo: ["postId": pid]
                    )
                }
            } catch {
                await MainActor.run {
                    ModalCoordinator.shared?.showToast(.init(message: "업로드 실패"))
                }
            }
        }
    }


    func delete(_ comment: Comment) {
        guard comment.userId == Auth.auth().currentUser?.uid else { return }
        db.collection("challengePosts")
            .document(postId)
            .collection("comments")
            .document(comment.id)
            .delete()
    }

    func report(_ comment: Comment) {
        let fn = Functions.functions(region: "asia-northeast3")
            .httpsCallable("reportComment")

        Task {
            do {
                _ = try await fn.call([
                    "postId":    postId,
                    "commentId": comment.id,
                ])
                ModalCoordinator.shared?.showToast(.init(message: "신고 완료"))
            } catch {
                ModalCoordinator.shared?.showToast(.init(message: "이미 신고했거나 오류"))
            }
        }
    }

    // MARK: – Listener
    private func startListener() {
        listener = db.collection("challengePosts")
            .document(postId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let raws = snap?.documents.compactMap(Comment.init) ?? []
                let blocked = BlockManager.shared.blockedUserIds
                self.comments = raws.filter { !blocked.contains($0.userId) }
                self.prefetchAuthors(from: self.comments)
            }
    }

    private func prefetchAuthors(from list: [Comment]) {
        let missing = Set(list.map(\.userId)).subtracting(userCache.keys)
        guard !missing.isEmpty else { return }
        userRepo.fetchUsers(withIds: Array(missing)) { [weak self] res in
            if case .success(let users) = res {
                users.forEach {
                    self?.userCache[$0.id] = LiteUser(
                        id: $0.id, nickname: $0.nickname, avatarURL: $0.effectiveProfileImageURL
                    )
                }
            }
        }
    }
}

/* ───────────── 로컬 금칙어 정규식 ───────────── */
private func hasBadWords(_ text: String) -> Bool {
    let pattern = "(시\\s*발|씨\\s*발|ㅅ\\s*ㅂ|좆|존나|f+u+c*k+|s+h+i+t+|b+i+t+c+h+)"
    return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}
