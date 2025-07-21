import SwiftUI
import FirebaseFirestore

struct HomeView: View {

    // MARK: – ViewModels & Env
    @StateObject private var vm = ChallengeViewModel()
    @StateObject private var camC = CameraCoordinator()
    @EnvironmentObject private var modalC: ModalCoordinator

    // MARK: – UI State
    @State private var selectedType: ChallengeType = .mandatory

    /// 댓글 시트 라우팅용
    @State private var commentSheetPost: Post?

    /// 게시물 단독 상세 라우팅용
    @State private var detailPost: Post?

    var body: some View {
        VStack(spacing: 0) {

            // ── 타입 세그먼트 ───────────────────────────────
            Picker("", selection: $selectedType) {
                Text(ChallengeType.mandatory.displayName)
                    .tag(ChallengeType.mandatory)
                Text(ChallengeType.open.displayName)
                    .tag(ChallengeType.open)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // ── 챌린지 리스트 ───────────────────────────────
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {

                    /* 진행 중 */
                    if !vm.active.filter({ $0.type == selectedType }).isEmpty {
                        SectionHeader(title: "진행 중")
                        ForEach(vm.active.filter { $0.type == selectedType }) { ch in
                            ChallengeCardView(challenge: ch, viewModel: vm)
                                .environmentObject(camC)
                                .padding(.horizontal, 8)
                        }
                    }

                    /* 종료 */
                    if !vm.closed.filter({ $0.type == selectedType }).isEmpty {
                        SectionHeader(title: "종료 • 7일 열람")
                        ForEach(vm.closed.filter { $0.type == selectedType }) { ch in
                            ChallengeCardView(challenge: ch, viewModel: vm)
                                .environmentObject(camC)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("챌린지")
        .background(Color("BackgroundPrimary").ignoresSafeArea())

        // ── 카메라 모달 ───────────────────────────────────
        .fullScreenCover(item: $camC.current) { ctx in
            CameraView(
                challengeId:    ctx.challengeId,
                participationId: ctx.participationId,
                onFinish:       { camC.dismiss() }
            )
        }

        // ───────────────────────────────────────────────
        // MARK: 📬 푸시/딥링크 → 게시물 or 댓글 이동
        // ───────────────────────────────────────────────
        .onReceive(NotificationCenter.default.publisher(for: .openPost)) { note in
            guard let (pId, cId) = note.object as? (String, String?) else { return }
            openPost(postId: pId, commentId: cId)
        }

        // cold-launch 보관분 소비
        .onAppear {
            if let p = PendingDeepLink.postId {
                let c = PendingDeepLink.commentId
                PendingDeepLink.postId = nil
                PendingDeepLink.commentId = nil
                openPost(postId: p, commentId: c)
            }
        }

        // ── 💬 댓글 Sheet ───────────────────────────────
        .sheet(item: $commentSheetPost) { post in
            CommentsSheet(post: post)
                .environmentObject(modalC)
        }

        // ── 📷 게시물 단독 상세 ───────────────────────────
        .sheet(item: $detailPost) { post in
            PostDetailView(post: post, allowComments: false)
                .environmentObject(modalC)
        }
    }

    // MARK: – Helpers
    private func openPost(postId: String, commentId: String?) {
        Task {
            guard let fetched = try? await fetchSinglePost(postId) else {
                modalC.showToast(.init(message: "게시물을 불러오지 못했어요"))
                return
            }

            // ▶︎ 빈 문자열·"null"·공백 무시
            let clean = commentId?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let isValidComment = clean != nil && !clean!.isEmpty && clean != "null"

            if isValidComment {
                commentSheetPost = fetched
            } else {
                detailPost = fetched
            }
        }
    }

    /// Firestore 단건 로드
    private func fetchSinglePost(_ id: String) async throws -> Post {
        let snap = try await Firestore.firestore()
            .collection("challengePosts")
            .document(id)
            .getDocument()

        guard snap.exists, let post = Post(snapshot: snap) else {
            throw NSError(domain: "post.notFound", code: 0)
        }
        return post
    }
}
