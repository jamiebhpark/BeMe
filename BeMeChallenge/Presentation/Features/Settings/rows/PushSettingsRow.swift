// Presentation/Features/Settings/rows/PushSettingsRow.swift
import SwiftUI
import UserNotifications

struct PushSettingsRow: View {
    @StateObject private var vm = NotificationSettingsViewModel()
    @EnvironmentObject private var modalC: ModalCoordinator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                HStack {
                    Text("푸시 알림")
                    Spacer()
                    ProgressView()
                }

            case .failed(let error):
                HStack {
                    Text("푸시 알림")
                    Spacer()
                    Image(systemName: "xmark.octagon")
                        .foregroundColor(.red)
                }
                .onTapGesture {
                    modalC.showToast(ToastItem(message: error.localizedDescription))
                    vm.refresh()
                }

            case .loaded(let enabled):
                HStack {
                    Text("푸시 알림")
                    Spacer()

                    if enabled {
                        Button("끄기") {
                            guard let url = URL(string: UIApplication.openSettingsURLString),
                                  UIApplication.shared.canOpenURL(url)
                            else { return }
                            UIApplication.shared.open(url)
                        }
                        .foregroundColor(.red)

                    } else {
                        Button("켜기") {
                            // 현재 권한 상태를 확인
                            UNUserNotificationCenter.current().getNotificationSettings { settings in
                                DispatchQueue.main.async {
                                    switch settings.authorizationStatus {
                                    case .notDetermined:
                                        // 최초 요청
                                        vm.requestPermission { granted in
                                            if !granted {
                                                modalC.showToast(ToastItem(message: vm.disableMessage()))
                                            }
                                            vm.refresh()
                                        }
                                    default:
                                        // 이미 거부된 상태 → 설정 열기
                                        guard let url = URL(string: UIApplication.openSettingsURLString),
                                              UIApplication.shared.canOpenURL(url)
                                        else { return }
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                vm.refresh()
            }
        }
    }
}
