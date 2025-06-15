//
//  ChallengeViewModel.swift
//  BeMeChallenge
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class ChallengeViewModel: ObservableObject {
    
    // MARK: - Published (UI 바인딩용)
    @Published private(set) var active:  [Challenge] = []   // 진행 중
    @Published private(set) var closed:  [Challenge] = []   // 종료 후 7일 열람
    @Published private(set) var todayParticipations: Set<String> = []
    
    /// 전체 리스트(디버깅·백업용)
    @Published private(set) var challengesState: Loadable<[Challenge]> = .idle
    
    // MARK: - Private
    private let service = ChallengeService.shared
    private let db      = Firestore.firestore()
    
    private var challengeListener:      ListenerRegistration?
    private var participationListener:  ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init / Deinit
    init() {
        startListeners()
        
        NotificationCenter.default.publisher(for: .didSignOut)
            .sink { [weak self] _ in
                Task { @MainActor in self?.stopListeners() }   // ✅
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .didSignIn)
            .sink { [weak self] _ in
                Task { @MainActor in self?.startListeners() }  // ✅
            }
            .store(in: &cancellables)
    }
    // MARK: - Public API
    /// Cloud Function으로 챌린지 참여
    func participate(in challenge: Challenge) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self, Auth.auth().currentUser != nil else {
                return promise(.failure(NSError(domain: "Auth", code: -1)))
            }
            self.service.participate(
                challengeId: challenge.id,
                type: challenge.type.rawValue,
                completion: promise
            )
        }
        .receive(on: DispatchQueue.main)
        .share()
        .eraseToAnyPublisher()
    }
    
    // MARK: - Firestore Listeners
    private func startListeners() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // 챌린지 목록
        challengesState = .loading
        challengeListener = db.collection("challenges")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err { self.challengesState = .failed(err); return }
                
                let list = snap?.documents.compactMap(Challenge.init) ?? []
                self.active = list.filter { $0.isActive }
                self.closed = list.filter { $0.within7days }
                
                self.challengesState = .loaded(list)
            }
        
        // 오늘 참여 현황
        let startOfDay = Calendar.current.startOfDay(for: Date())
        participationListener = db.collection("users").document(uid)
            .collection("participations")
            .whereField("date", isGreaterThanOrEqualTo: startOfDay)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let ids = snap?.documents.compactMap {
                    $0.data()["challengeId"] as? String
                } ?? []
                self.todayParticipations = Set(ids)
            }
    }
    
    private func stopListeners() {
        challengeListener?.remove();      challengeListener = nil
        participationListener?.remove();  participationListener = nil
        
        active.removeAll()
        closed.removeAll()
        challengesState = .idle
        todayParticipations.removeAll()
    }
}
