//
//  ChallengeDetailViewModel.swift
//  BeMeChallenge
//
//  v5 – Safe-Search ‘rejected’ 필드 및 차단 사용자 필터링 반영
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// BlockManager.swift 에 구현된 차단 사용자 목록 API
// 예: BlockManager.shared.blockedUserIds -> Set<String>

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
        // ① 로그인 해제 시 상태 초기화
        NotificationCenter.default.publisher(for: .didSignOut)
            .sink { [weak self] _ in
                Task { @MainActor in self?.resetState() }
            }
            .store(in: &cancellables)
        
        // ② 댓글 작성 성공 → 즉시 commentsCount +1
        NotificationCenter.default.publisher(for: .commentAdded)
            .sink { [weak self] note in
                guard
                    let self,
                    let pid = note.userInfo?["postId"] as? String,
                    let idx = self.posts.firstIndex(where: { $0.id == pid })
                else { return }
                
                let current = self.posts[idx]
                let updated = current.copy(commentsCount: current.commentsCount + 1)
                self.posts[idx] = updated
            }
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
        db.collection("challengePosts").document(post.id).delete { [weak self] err in
            if err == nil {
                self?.posts.removeAll { $0.id == post.id }
            }
        }
    }

    // ───────── HELPERS ─────────
    private func fetchPage(after doc: DocumentSnapshot?) async throws
        -> ([Post], DocumentSnapshot?)
    {
        var query = db.collection("challengePosts")
            .whereField("challengeId", isEqualTo: currentCID)
            .whereField("reported",    isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)

        if scope == .mine, let uid = Auth.auth().currentUser?.uid {
            query = query.whereField("userId", isEqualTo: uid)
        }
        if let doc {
            query = query.start(afterDocument: doc)
        }

        let snap = try await query.getDocuments()
        let raw  = snap.documents.compactMap(Post.init)

        // ⭐️ ‘rejected == true’ 제거
        // ⭐️ 차단된 사용자(userId) 필터링
        let blocked = BlockManager.shared.blockedUserIds
        let filtered = raw.filter {
            $0.rejected != true
            && !blocked.contains($0.userId)
        }

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
        let original = posts[idx]
        var reactions = original.reactions
        reactions["❤️", default: 0] = max(0, reactions["❤️", default: 0] + delta)
        posts[idx] = original.copy(withReactions: reactions)
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
