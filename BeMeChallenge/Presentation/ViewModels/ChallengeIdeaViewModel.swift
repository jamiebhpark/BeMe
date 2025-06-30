//
//  ChallengeIdeaViewModel.swift
//  BeMeChallenge
//

import SwiftUI
import FirebaseFirestore

@MainActor
final class ChallengeIdeaViewModel: ObservableObject {

    // ── UI에 노출되는 상태값 ───────────────────────────────
    @Published var ideas:      [ChallengeIdea] = []
    @Published var showSubmit = false

    // 🔥 인기 승격 기준
    private let hotThreshold = 30

    // ── Firestore 리스너 ────────────────────────────────
    private var listener: ListenerRegistration?
    func start() {
        listener = ChallengeIdeaService.shared
            .listenRecent { [weak self] in self?.ideas = $0 }
    }
    deinit { listener?.remove() }

    // ── 파생 컬렉션 ─────────────────────────────────────
    var popular: [ChallengeIdea] {
        ideas.filter { $0.likeCount >= hotThreshold }
             .sorted { $0.likeCount >  $1.likeCount }
    }
    var latest: [ChallengeIdea] {
        ideas.filter { $0.likeCount < hotThreshold }
             .sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
    }

    // ── 단일 아이디어 액션 ──────────────────────────────
    func toggleLike(_ idea: ChallengeIdea) {
        ChallengeIdeaService.shared.toggleLike(for: idea)
    }
    func archive(_ idea: ChallengeIdea) {
        ChallengeIdeaService.shared.archiveIdea(idea)
    }

    // ── 새 제안 올리기 ─────────────────────────────────
    func submitIdea(title: String,
                    desc:  String) async -> Result<Void, Error> {
        do {
            if try await ChallengeIdeaService.shared.todaysIdeaExists() {
                return .failure(NSError(domain: "Idea", code: 1,
                    userInfo: [NSLocalizedDescriptionKey:"하루에 한 번만 제안할 수 있어요"]))
            }
            return await ChallengeIdeaService.shared
                   .submitIdea(title: title, desc: desc)
        } catch { return .failure(error) }
    }
}
