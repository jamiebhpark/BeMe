// Domain/Models/LiteUser.swift (새 파일)
import Foundation

/// Firestore와 완전히 무관한, UI 표시용 최소 모델
struct LiteUser: Identifiable, Hashable {
    let id: String
    let nickname: String
    let avatarURL: URL?              // ← 한 줄 추가
}

// PostCellView 와 호환용 별칭
extension LiteUser {
    var effectiveProfileImageURL: URL? { avatarURL }
}
