// App/Coordinators/CameraCoordinator.swift
import SwiftUI

/// 풀-스크린 카메라 모달에 필요한 컨텍스트
struct CameraContext: Identifiable, Hashable {
    let id = UUID()
    let challengeId:    String
    let participationId: String
}

/// 카메라 전용 코디네이터
final class CameraCoordinator: ObservableObject {

    /// nil → 모달 닫힘
    @Published var current: CameraContext? = nil

    /// 카메라 모달 열기
    func presentCamera(for challengeId: String, participationId: String) {
        current = CameraContext(challengeId: challengeId,
                                participationId: participationId)
    }

    /// 닫기 (= 흐름 종료)
    func dismiss() { current = nil }
}
