// App/Coordinators/CameraCoordinator.swift
import SwiftUI

/// 카메라 전용 코디네이터 (Full-Screen Modal 관리)
final class CameraCoordinator: ObservableObject {
    /// 현재 찍고 있는 챌린지 ID (nil → 모달 닫힘)
    @Published var currentChallengeID: String? = nil
    
    /// 카메라 모달 열기
    func presentCamera(for challengeID: String) {
        currentChallengeID = challengeID
    }
    
    /// 닫기(= 흐름 종료)
    func dismiss() {
        currentChallengeID = nil
    }
}
