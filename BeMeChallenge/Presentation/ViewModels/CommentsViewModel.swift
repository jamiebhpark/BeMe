//
//  CommentsViewModel.swift
//  BeMeChallenge
//
//  Updated: 2025-07-22
//  ─────────────────────────────────────────────
//  • isAdmin 상태 보유/갱신
//  • admin 인 경우 reported·block 필터 해제
//  • 삭제/수정 권한: 작성자 ▸or▸ admin
//  • Comment.copy(isAdmin:) 로 View 쪽에 권한 전달
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import Combine

// MARK: – Notification keys
extension Notification.Name {
    static let commentAdded        = Notification.Name("commentAdded")
    /// 피드 말풍선 숫자 동기화 (userInfo: ["postId": String, "delta": Int])
    static let commentCountChanged = Notification.Name("commentCountChanged")
}

@MainActor
final class CommentsViewModel: ObservableObject {

    // ───────── OUTPUT ─────────
    @Published private(set) var comments: [Comment] = []
    @Published private(set) var isSending           = false
    @Published private(set) var userCache: [String: LiteUser] = [:]

    // ───────── PRIVATE ─────────
    private let postId: String
    private let db     = Firestore.firestore()
    private var listener:    ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    private let userRepo: UserRepositoryProtocol = UserRepository()

    /// 현재 사용자 admin 여부
    private var isAdmin   = false
    /// 원본 스냅샷(필터 전) 캐싱 – admin flag 바뀔 때 재사용
    private var rawsCache = [Comment]()

    // MARK: – Init / Deinit
    init(postId: String) {
        self.postId = postId
        computeAdminFlag()   // 최초 계산
        startListener()

        // 로그인/로그아웃 될 때 admin flag 재계산
        NotificationCenter.default.publisher(for: .didSignIn)
            .sink { [weak self] _ in self?.computeAdminFlag() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .didSignOut)
            .sink { [weak self] _ in
                self?.isAdmin   = false
                self?.comments  = self?.filterAndMark(self?.rawsCache ?? []) ?? []
            }
            .store(in: &cancellables)
    }
    deinit { listener?.remove() }

    // ───────────────────────────────────────────────
    // MARK: Add Comment
    // ───────────────────────────────────────────────
    func addComment(text: String) {
        guard !isSending, Auth.auth().currentUser != nil else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 300 else { return }

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

                // 🔔 말풍선 +1
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

    // ───────────────────────────────────────────────
    // MARK: Edit Comment
    // ───────────────────────────────────────────────
    func edit(_ comment: Comment, newText: String) {
        guard Auth.auth().currentUser != nil else { return }
        guard comment.userId == Auth.auth().currentUser?.uid || isAdmin else { return }

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

    // ───────────────────────────────────────────────
    // MARK: Delete Comment
    // ───────────────────────────────────────────────
    func delete(_ comment: Comment) {
        guard Auth.auth().currentUser != nil else { return }
        guard comment.userId == Auth.auth().currentUser?.uid || isAdmin else { return }

        db.collection("challengePosts")
          .document(postId)
          .collection("comments")
          .document(comment.id)
          .delete { err in
              if let err {
                  ModalCoordinator.shared?.showToast(.init(message: err.localizedDescription))
              } else {
                  NotificationCenter.default.post(
                      name: .commentCountChanged,
                      object: nil,
                      userInfo: ["postId": self.postId, "delta": -1]
                  )
              }
          }
    }

    // ───────────────────────────────────────────────
    // MARK: Report Comment  (일반 사용자용)
    // ───────────────────────────────────────────────
    func report(_ comment: Comment) {
        guard !isAdmin else { return }   // 관리자는 신고 대신 직접 삭제

        let fn = Functions.functions(region: "asia-northeast3")
            .httpsCallable("reportComment")

        Task {
            do {
                _ = try await fn.call([
                    "postId"   : postId,
                    "commentId": comment.id,
                ])
                // UI 즉시 제거
                comments.removeAll { $0.id == comment.id }
                NotificationCenter.default.post(
                    name: .commentCountChanged,
                    object: nil,
                    userInfo: ["postId": postId, "delta": -1]
                )
                ModalCoordinator.shared?.showToast(.init(message: "신고 완료"))
            } catch {
                ModalCoordinator.shared?.showToast(.init(message: "이미 신고했거나 오류"))
            }
        }
    }

    // ───────────────────────────────────────────────
    // MARK: Realtime Listener
    // ───────────────────────────────────────────────
    private func startListener() {
        listener = db.collection("challengePosts")
            .document(postId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }

                self.rawsCache = snap?.documents.compactMap(Comment.init) ?? []
                self.comments  = self.filterAndMark(self.rawsCache)
                self.prefetchAuthors(from: self.comments)
            }
    }

    /// admin·차단 상태를 반영해 list 를 필터링하고, 권한 플래그를 주입
    private func filterAndMark(_ list: [Comment]) -> [Comment] {
        let blocked = BlockManager.shared.blockedUserIds
        let visible = isAdmin ? list
                              : list.filter { !$0.reported && !blocked.contains($0.userId) }
        return visible.map { $0.copy(isAdmin: isAdmin) }
    }

    // ───────────────────────────────────────────────
    // MARK: Author Prefetch
    // ───────────────────────────────────────────────
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

    // ───────────────────────────────────────────────
    // MARK: Admin Flag 계산
    // ───────────────────────────────────────────────
    private func computeAdminFlag() {
        Task.detached { [weak self] in
            guard let self,
                  let user = Auth.auth().currentUser else { return }

            let tok = try? await user.getIDTokenResult()
            await MainActor.run {
                self.isAdmin  = (tok?.claims["isAdmin"] as? Bool) ?? false
                self.comments = self.filterAndMark(self.rawsCache)   // flag 바뀌자마자 갱신
            }
        }
    }

    // ───────────────────────────────────────────────
    // MARK: Profanity Filter
    // ───────────────────────────────────────────────
    private func hasBadWords(_ text: String) -> Bool {
        let rx = "(시\\s*발|씨\\s*발|ㅅ\\s*ㅂ|좆|존나|f+u+c*k+|s+h+i+t+|b+i+t+c+h+)"
        return text.range(of: rx, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
