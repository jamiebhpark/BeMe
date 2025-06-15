// Presentation/ViewModels/NotificationSettingsViewModel.swift
import Foundation
import UserNotifications
import UIKit
import Combine

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    
    /// 권한 상태 Loadable
    @Published private(set) var state: Loadable<Bool> = .idle          // true = 허용
    private var cancellables = Set<AnyCancellable>()
    
    init() { refresh() }
    
    /// 최신 권한 상태를 조회
    func refresh() {
        state = .loading
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                guard let self else { return }
                let granted = settings.authorizationStatus == .authorized ||
                              settings.authorizationStatus == .provisional
                self.state = .loaded(granted)
            }
        }
    }
    
    /// 사용자가 토글을 켰을 때 처리
    func requestPermission() {
        state = .loading
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert,.sound,.badge]) { [weak self] granted, err in
                Task { @MainActor in
                    if let err { self?.state = .failed(err) }
                    else {
                        if granted { UIApplication.shared.registerForRemoteNotifications() }
                        self?.state = .loaded(granted)
                    }
                }
            }
    }
    
    /// 토글을 끄면 iOS 내에서 해제할 수 없으므로 안내 문구 반환
    func disableMessage() -> String {
        "알림 해제는 ‘설정 앱 > BeMe Challenge > 알림’ 에서 가능합니다."
    }
}
// NotificationSettingsViewModel.swift 에 다음 메서드 추가 및 수정
extension NotificationSettingsViewModel {
    /// 콜백으로 성공 여부 전달하도록 requestPermission 수정
    func requestPermission(completion: @escaping (Bool) -> Void) {
        state = .loading
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, err in
                Task { @MainActor in
                    if let err {
                        self?.state = .failed(err)
                        completion(false)
                    } else {
                        if granted {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                        self?.state = .loaded(granted)
                        completion(granted)
                    }
                }
            }
    }
}
