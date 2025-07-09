//
//  BlockManager.swift
//  BeMeChallenge
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class BlockManager: ObservableObject {
    static let shared = BlockManager()

    /// 차단된 사용자 ID 집합
    @Published private(set) var blockedUserIds: Set<String> = []

    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // 로그인/로그아웃 시 구독 초기화
        NotificationCenter.default.publisher(for: .didSignIn)
            .sink { [weak self] _ in self?.subscribeToBlockedUsers() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .didSignOut)
            .sink { [weak self] _ in self?.clearBlockedUsers() }
            .store(in: &cancellables)
        // 앱 런칭 직후에도 시도
        subscribeToBlockedUsers()
    }

    /// Firestore 구독 시작
    private func subscribeToBlockedUsers() {
        listener?.remove()
        listener = nil
        guard let me = Auth.auth().currentUser?.uid else { return }
        listener = Firestore.firestore()
            .collection("users/\(me)/blockedUsers")
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                self?.blockedUserIds = Set(docs.map { $0.documentID })
            }
    }

    /// 차단 목록을 완전 초기화합니다 (로그아웃 등)
    func clearBlockedUsers() {
        listener?.remove()
        listener = nil
        blockedUserIds.removeAll()
    }
}
