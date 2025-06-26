//
//  ChallengeIdeaViewModel.swift
//  BeMeChallenge
//

import SwiftUI
import FirebaseFirestore

@MainActor
final class ChallengeIdeaViewModel: ObservableObject {
    @Published var ideas: [ChallengeIdea] = []
    @Published var showSubmit = false
    
    private var listener: ListenerRegistration?
    private let hotThreshold = 30       // 🔥 승격 기준
    // MARK: - 라이프사이클
    func start() {
        listener = ChallengeIdeaService.shared
            .listenRecent { [weak self] in self?.ideas = $0 }
    }
    deinit { listener?.remove() }
    
    // MARK: - 파생 컬렉션
    var popular: [ChallengeIdea] {
        ideas.filter { $0.likeCount >= hotThreshold }
            .sorted { $0.likeCount > $1.likeCount }
    }
    var latest: [ChallengeIdea] {
        ideas.filter { $0.likeCount < hotThreshold }
            .sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
    }
    
    // MARK: - 액션
    func toggleLike(_ idea: ChallengeIdea) {
        ChallengeIdeaService.shared.toggleLike(for: idea)
    }
    func archive(_ idea: ChallengeIdea) {        // SwipeAction
        ChallengeIdeaService.shared.archiveIdea(idea)
    }
    
    func submitIdea(title: String,
                    desc: String) async -> Result<Void, Error> {
        do {
            if try await ChallengeIdeaService.shared.todaysIdeaExists() {
                return .failure(NSError(domain: "Idea", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "하루에 한 번만 제안할 수 있어요"]))
            }
            return await ChallengeIdeaService.shared.submitIdea(title: title, desc: desc)
        } catch {
            return .failure(error)          // ❗️try 에러 캐치
        }
    }
}
