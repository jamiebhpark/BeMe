//
//  Navigator.swift
//  BeMeChallenge
//
//  역할: 외부 이벤트(푸시·딥링크 등)를 앱의 네비게이션 스택으로 전달
//

import Foundation

// ① 알림 이름 정의 ─ 중복 선언 주의!
extension Notification.Name {
    static let openPost      = Notification.Name("openPost")      // 게시물 상세
    static let openChallenge = Notification.Name("openChallenge") // 챌린지 루트
}

final class Navigator {
    static let shared = Navigator()
    private init() {}

    /// 게시물 화면으로 이동. `commentId` 가 nil 이면 게시물만 표시
    func openPost(_ postId: String, commentId: String? = nil) {
        NotificationCenter.default.post(
            name: .openPost,
            object: (postId, commentId)   // `(String, String?)` 튜플 전달
        )
    }

    /// 챌린지 상세(루트)로 이동
    func openChallenge(_ id: String) {
        NotificationCenter.default.post(
            name: .openChallenge,
            object: id                    // `String`
        )
    }
}
