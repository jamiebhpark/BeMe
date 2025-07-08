//
//  ChallengeDetailViewModel.swift
//  BeMeChallenge
//
//  v4 – Safe-Search ‘rejected’ 필드 반영
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

    // “전체 / 내 게시물” 세그
    @Published var scope: FeedScope = .all {
        didSet { Task { await loadInitial(challengeId: currentCID) } }
    }

    // ───────── PRIVATE ─────────
    private let db       = Firestore.firestore()
    private let pageSize = 20

    private var lastDoc : DocumentSnapshot?
    private var currentCID = ""
    private var cancellables = Set<AnyCancellable>()

    private let userRepo: UserRepositoryProtocol = UserRepository()

    // MARK: Init
    init() {
        NotificationCenter.default.publisher(for: .didSignOut)
            .sink { [weak self] _ in Task { @MainActor in self?.resetState() } }
            .store(in: &cancellables)
    }

    // ───────── PUBLIC API ─────────
    func loadInitial(challengeId cid: String) async {
        currentCID = cid
        resetState()
        postsState = .loading

        do {
            let (list, last) = try await fetchPage(after: nil)
            posts     = list
            lastDoc   = last
            postsState = .loaded(())
            prefetchAuthors(from: list)
        } catch { postsState = .failed(error) }
    }

    func loadMore() async {
        guard !isLoadingMore, let lastDoc else { return }
        isLoadingMore = true; defer { isLoadingMore = false }

        do {
            let (list, last) = try await fetchPage(after: lastDoc)
            posts += list
            self.lastDoc = last
            prefetchAuthors(from: list)
        } catch { print("🚨 pagination :", error.localizedDescription) }
    }

    func like(_ post: Post) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        applyDelta(+1, for: post)
        ReactionService.shared.updateReaction(
            forPost: post.id, reactionType: "❤️", userId: uid
        ) { [weak self] res in
            if case .failure = res { Task { @MainActor in self?.applyDelta(-1, for: post) } }
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

    // ───────── HELPERS ─────────
    private func fetchPage(after doc: DocumentSnapshot?) async throws
    -> ([Post], DocumentSnapshot?) {

        var query = db.collection("challengePosts")
            .whereField("challengeId", isEqualTo: currentCID)
            .whereField("reported",    isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)

        if scope == .mine, let uid = Auth.auth().currentUser?.uid {
            query = query.whereField("userId", isEqualTo: uid)
        }
        if let doc { query = query.start(afterDocument: doc) }

        let snap = try await query.getDocuments()

        // ⭐️ ‘rejected == true’ 제거, nil / false 는 그대로
        let raw  = snap.documents.compactMap(Post.init)
        let list = raw.filter { $0.rejected != true }

        return (list, snap.documents.last)
    }

    private func resetState() {
        posts = []; userCache.removeAll()
        lastDoc = nil; postsState = .idle
    }

    private func applyDelta(_ delta: Int, for post: Post) {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        var p = posts[idx]
        var map = p.reactions
        map["❤️", default: 0] = max(0, map["❤️", default: 0] + delta)
        p = p.copy(withReactions: map)
        posts[idx] = p
    }

    private func prefetchAuthors(from page: [Post]) {
        let missing = Set(page.map(\.userId)).subtracting(userCache.keys)
        guard !missing.isEmpty else { return }

        userRepo.fetchUsers(withIds: Array(missing)) { [weak self] res in
            if case .success(let users) = res {
                for u in users {
                    self?.userCache[u.id] = LiteUser(
                        id: u.id, nickname: u.nickname, avatarURL: u.effectiveProfileImageURL
                    )
                }
            }
        }
    }
}
