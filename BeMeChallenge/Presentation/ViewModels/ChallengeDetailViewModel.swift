//
//  ChallengeDetailViewModel.swift
//  BeMeChallenge
//
//  v7 – commentCountChanged(delta)로 말풍선 숫자 ± 실시간 반영
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class ChallengeDetailViewModel: ObservableObject {

    // ───────── OUTPUT ─────────
    @Published private(set) var posts:      [Post]         = []
    @Published private(set) var postsState: Loadable<Void> = .idle
    @Published private(set) var isLoadingMore              = false
    @Published private(set) var userCache:  [String: LiteUser] = [:]

    /// “전체 / 내 게시물” 세그
    @Published var scope: FeedScope = .all {
        didSet { Task { await loadInitial(challengeId: currentCID) } }
    }

    // ───────── PRIVATE ─────────
    private let db         = Firestore.firestore()
    private let pageSize   = 20
    private var lastDoc   : DocumentSnapshot?
    private(set) var currentCID = ""   // ← 접근자를 fileprivate → internal 로 완화
    private var cancellables = Set<AnyCancellable>()
    private let userRepo: UserRepositoryProtocol = UserRepository()

    // MARK: Init ---------------------------------------------------------
    init() {
        // 로그아웃 시 상태 초기화
        NotificationCenter.default.publisher(for: .didSignOut)
            .sink { [weak self] _ in Task { @MainActor in self?.resetState() } }
            .store(in: &cancellables)

        // 🔔 댓글 추가/삭제 → delta 반영
        NotificationCenter.default.publisher(for: .commentCountChanged)
            .sink { [weak self] note in self?.handleCommentDelta(note) }
            .store(in: &cancellables)
    }

    // ───────── PUBLIC API ─────────
    func loadInitial(challengeId cid: String) async {
        currentCID = cid
        resetState()
        postsState = .loading

        do {
            let (list, last) = try await fetchPage(after: nil)
            posts      = list
            lastDoc    = last
            postsState = .loaded(())
            prefetchAuthors(from: list)
        } catch {
            postsState = .failed(error)
        }
    }

    func loadMore() async {
        guard !isLoadingMore, let lastDoc else { return }
        isLoadingMore = true; defer { isLoadingMore = false }

        do {
            let (list, last) = try await fetchPage(after: lastDoc)
            posts += list
            self.lastDoc = last
            prefetchAuthors(from: list)
        } catch {
            print("🚨 pagination :", error.localizedDescription)
        }
    }

    func like(_ post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        applyDelta(+1, for: post)
        ReactionService.shared.updateReaction(
            forPost: post.id, reactionType: "❤️", userId: uid
        ) { [weak self] res in
            if case .failure = res {
                Task { @MainActor in self?.applyDelta(-1, for: post) }
            }
        }
    }

    func report(_ post: Post) {
        ReportService.shared.reportPost(postId: post.id) { [weak self] res in
            if case .success = res {
                Task { @MainActor in
                    self?.posts.removeAll { $0.id == post.id }
                }
            }
        }
    }

    func deletePost(_ post: Post) {
        db.collection("challengePosts")
          .document(post.id)
          .delete { [weak self] err in
              if err == nil {
                  self?.posts.removeAll { $0.id == post.id }
              }
          }
    }

    // 🆕 캡션 수정 --------------------------------------------------------
    func updateCaption(_ post: Post, to newText: String) {
        guard Auth.auth().currentUser?.uid == post.userId else { return }

        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 80, !hasBadWords(trimmed) else {
            ModalCoordinator.shared?.showToast(.init(message: "부적절하거나 80자 초과"))
            return
        }

        db.collection("challengePosts").document(post.id)
            .updateData(["caption": trimmed]) { [weak self] err in
                guard err == nil else {
                    ModalCoordinator.shared?.showToast(.init(message: err!.localizedDescription))
                    return
                }
                if let idx = self?.posts.firstIndex(where: { $0.id == post.id }) {
                    self?.posts[idx] = post.copy(caption: trimmed)
                }
            }
    }
    // -------------------------------------------------------------------

    // ───────── HELPERS ─────────
    private func fetchPage(after doc: DocumentSnapshot?) async throws
          -> ([Post], DocumentSnapshot?) {

        var q = db.collection("challengePosts")
            .whereField("challengeId", isEqualTo: currentCID)
            .whereField("reported",    isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)

        if scope == .mine, let uid = Auth.auth().currentUser?.uid {
            q = q.whereField("userId", isEqualTo: uid)
        }
        if let doc { q = q.start(afterDocument: doc) }

        let snap = try await q.getDocuments()
        let raw  = snap.documents.compactMap(Post.init)

        let blocked  = BlockManager.shared.blockedUserIds
        let filtered = raw.filter { $0.rejected != true && !blocked.contains($0.userId) }

        return (filtered, snap.documents.last)
    }

    private func resetState() {
        posts = []
        userCache.removeAll()
        lastDoc = nil
        postsState = .idle
    }

    private func applyDelta(_ delta: Int, for post: Post) {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        var reactions = posts[idx].reactions
        reactions["❤️", default: 0] = max(0, reactions["❤️", default: 0] + delta)
        posts[idx] = posts[idx].copy(withReactions: reactions)
    }

    private func prefetchAuthors(from page: [Post]) {
        let missing = Set(page.map(\.userId)).subtracting(userCache.keys)
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

    // 🔔 commentCountChanged handler (± delta)
    private func handleCommentDelta(_ note: Notification) {
        guard
            let pid   = note.userInfo?["postId"] as? String,
            let delta = note.userInfo?["delta"]  as? Int,
            let idx   = posts.firstIndex(where: { $0.id == pid })
        else { return }

        let cur = posts[idx]
        posts[idx] = cur.copy(commentsCount: max(0, cur.commentsCount + delta))
    }

    // Profanity filter (caption / comment 공용)
    private func hasBadWords(_ text: String) -> Bool {
        let rx = "(시\\s*발|씨\\s*발|ㅅ\\s*ㅂ|좆|존나|f+u+c*k+|s+h+i+t+|b+i+t+c+h+)"
        return text.range(of: rx, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
