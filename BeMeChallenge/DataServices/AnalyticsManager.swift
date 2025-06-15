// AnalyticsManager.swift
import Foundation
import FirebaseAnalytics

/// Firebase Analytics를 활용하여 앱의 주요 이벤트를 로깅하는 싱글턴 클래스
class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    /// 일반 이벤트 로그 기록 (Firebase Analytics API 호출)
    func logEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
        print("Logged event: \(eventName), parameters: \(String(describing: parameters))")
    }
    
    // MARK: - 구체 이벤트 로깅 예제
    
    /// 소셜 로그인 이벤트 로깅
    /// - Parameters:
    ///   - method: "apple" 또는 "google"
    ///   - success: 로그인 성공 여부
    func logUserLogin(method: String, success: Bool) {
        logEvent("user_login", parameters: [
            "method": method,
            "success": success ? "true" : "false"
        ])
    }
    
    /// 챌린지 참여 이벤트 로깅
    /// - Parameters:
    ///   - challengeId: 참여한 챌린지 ID
    ///   - type: 챌린지 유형 ("필수" 또는 "오픈")
    func logChallengeParticipation(challengeId: String, type: String) {
        logEvent("challenge_participation", parameters: [
            "challengeId": challengeId,
            "type": type
        ])
    }
    
    /// 사진 업로드 이벤트 로깅
    /// - Parameters:
    ///   - challengeId: 업로드한 챌린지 ID
    ///   - uploadTime: 업로드에 소요된 시간 (밀리초)
    func logPhotoUpload(challengeId: String, uploadTime: Double) {
        logEvent("photo_upload_success", parameters: [
            "challengeId": challengeId,
            "upload_time_ms": uploadTime
        ])
    }
    
    /// 이모티콘 반응 클릭 이벤트 로깅
    /// - Parameters:
    ///   - challengeId: 해당 챌린지 ID
    ///   - reactionType: 반응 이모지 ("❤️", "👍", "😆", "🔥" 등)
    func logReactionClick(challengeId: String, reactionType: String) {
        logEvent("reaction_click", parameters: [
            "challengeId": challengeId,
            "reactionType": reactionType
        ])
    }
    
    /// 프로필 달력 조회 이벤트 로깅
    /// - Parameters:
    ///   - userId: 조회한 사용자 ID
    ///   - dateRange: 조회한 날짜 범위 (예: "2024-01")
    func logProfileCalendarView(userId: String, dateRange: String) {
        logEvent("profile_calendar_view", parameters: [
            "userId": userId,
            "date_range": dateRange
        ])
    }
}
