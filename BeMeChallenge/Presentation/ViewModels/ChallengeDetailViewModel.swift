//
//  ChallengeDetailViewModel.swift
//  BeMeChallenge
//
//  Updated: 2025-07-22
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class ChallengeDetailViewModel: ObservableObject {

    // ───────── OUTPUT ─────────
    @Published private(set) var posts: [Post]               = []
    @Published private(set) var postsState: Loadable<Void>  = .idle
    @Published private(set) var isLoadingMore               = false
    @Published private(set) var userCache: [String: LiteUser] = [:]   // ← 고침

    /// “전체 / 내 게시물” 세그
    @Published var scope: FeedScope = .all {
        didSet { Task { await loadInitial(challengeId: currentCID) } }
    }

    // ───────── PRIVATE ─────────
    private let db       = Firestore.firestore()
    private let pageSize = 20

    private var lastDoc: DocumentSnapshot?
    private(set) var currentCID = ""
    private var cancellables    = Set<AnyCancellable>()
    private let userRepo: UserRepositoryProtocol = UserRepository()

    /// 현재 사용자 admin 여부
    private var isAdmin = false

    // MARK: - Init
    init() {
        computeAdminFlag()                                     // 최초

        NotificationCenter.default.publisher(for: .didSignIn)
            .sink { [weak self] _ in self?.computeAdminFlag() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .didSignOut)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.isAdmin = false
                    self?.resetState()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .commentCountChanged)
            .sink { [weak self] n in self?.handleCommentDelta(n) }
            .store(in: &cancellables)
    }

    // MARK: - Public API
    func loadInitial(challengeId cid: String) async {
        currentCID = cid
        resetState()
        postsState = .loading

        do {
            let (page, last) = try await fetchPage(after: nil)
            posts      = page
            lastDoc    = last
            postsState = .loaded(())
            prefetchAuthors(from: page)
        } catch {
            postsState = .failed(error)
        }
    }

    func loadMore() async {
        guard !isLoadingMore, let lastDoc else { return }
        isLoadingMore = true; defer { isLoadingMore = false }

        do {
            let (page, last) = try await fetchPage(after: lastDoc)
            posts += page
            self.lastDoc = last
            prefetchAuthors(from: page)
        } catch { print("🚨 pagination:", error.localizedDescription) }
    }

    // like / report / delete / caption …(기존과 동일) -------------------
    func like(_ post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        applyDelta(+1, for: post)
        ReactionService.shared.updateReaction(forPost: post.id,
                                              reactionType: "❤️",
                                              userId: uid) { [weak self] res in
            if case .failure = res {
                Task { @MainActor in self?.applyDelta(-1, for: post) }
            }
        }
    }

    func report(_ post: Post) {
        ReportService.shared.reportPost(postId: post.id) { [weak self] res in
            if case .success = res {
                Task { @MainActor in self?.posts.removeAll { $0.id == post.id } }
            }
        }
    }

    func deletePost(_ post: Post) {
        db.collection("challengePosts").document(post.id).delete { [weak self] err in
            if err == nil { self?.posts.removeAll { $0.id == post.id } }
        }
    }

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
                if let i = self?.posts.firstIndex(where: { $0.id == post.id }) {
                    self?.posts[i] = post.copy(caption: trimmed)
                }
            }
    }

    // MARK: - Helpers
    private func fetchPage(after doc: DocumentSnapshot?) async throws
          -> ([Post], DocumentSnapshot?) {

        var q = db.collection("challengePosts")
            .whereField("challengeId", isEqualTo: currentCID)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)

        if !isAdmin { q = q.whereField("reported", isEqualTo: false) }

        if scope == .mine, let uid = Auth.auth().currentUser?.uid {
            q = q.whereField("userId", isEqualTo: uid)
        }
        if let doc { q = q.start(afterDocument: doc) }

        let snap = try await q.getDocuments()
        let raw  = snap.documents.compactMap(Post.init)

        let blocked = BlockManager.shared.blockedUserIds
        let result  = isAdmin ? raw
                              : raw.filter { $0.rejected != true && !blocked.contains($0.userId) }

        return (result, snap.documents.last)                 // ← copy(isAdmin:) 제거
    }

    private func resetState() {
        posts.removeAll()
        userCache.removeAll()
        lastDoc = nil
        postsState = .idle
    }

    private func applyDelta(_ d: Int, for post: Post) {
        guard let i = posts.firstIndex(where: { $0.id == post.id }) else { return }
        var r = posts[i].reactions
        r["❤️", default: 0] = max(0, r["❤️", default: 0] + d)
        posts[i] = posts[i].copy(withReactions: r)
    }

    private func prefetchAuthors(from page: [Post]) {
        let need = Set(page.map(\.userId)).subtracting(userCache.keys)
        guard !need.isEmpty else { return }

        userRepo.fetchUsers(withIds: Array(need)) { [weak self] res in
            if case .success(let users) = res {
                users.forEach {
                    self?.userCache[$0.id] = LiteUser(id: $0.id,
                                                      nickname: $0.nickname,
                                                      avatarURL: $0.effectiveProfileImageURL)
                }
            }
        }
    }

    private func handleCommentDelta(_ n: Notification) {
        guard
            let pid   = n.userInfo?["postId"] as? String,
            let delta = n.userInfo?["delta"]  as? Int,
            let i     = posts.firstIndex(where: { $0.id == pid })
        else { return }

        let cur = posts[i]
        posts[i] = cur.copy(commentsCount: max(0, cur.commentsCount + delta))
    }

    private func computeAdminFlag() {
        Task.detached { [weak self] in
            // 1️⃣ 백그라운드에서 토큰만 가져옴 — self 를 전혀 사용하지 않음
            guard let user = Auth.auth().currentUser else { return }
            let tok = try? await user.getIDTokenResult()
            let flag = (tok?.claims["isAdmin"] as? Bool) ?? false

            // 2️⃣ MainActor 로 돌아온 뒤에만 self 접근
            await MainActor.run { [weak self] in
                self?.isAdmin = flag
            }
        }
    }

    private func hasBadWords(_ t: String) -> Bool {
        let rx = "(시\\s*발|씨\\s*발|ㅅ\\s*ㅂ|좆|존나|f+u+c*k+|s+h+i+t+|b+i+t+c+h+)"
        return t.range(of: rx, options: [.regularExpression,.caseInsensitive]) != nil
    }
}
