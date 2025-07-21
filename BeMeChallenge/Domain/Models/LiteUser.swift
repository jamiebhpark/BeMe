//
//  LiteUser.swift
//

import Foundation

/// Firestore를 조회해 얻은 “최소 프로필”
/// - UI 표시에 필요한 닉네임/아바타만 보유
struct LiteUser: Identifiable, Hashable {
    let id: String
    let nickname: String
    let avatarURL: URL?
}

// (PostCellView 호환용) 프로필 이미지 URL 별칭
extension LiteUser {
    var effectiveProfileImageURL: URL? { avatarURL }
}
