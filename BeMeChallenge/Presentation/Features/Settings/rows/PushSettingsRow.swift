//
//  Presentation/Features/Settings/Rows/PushSettingsRow.swift
//

import SwiftUI
import UserNotifications

struct PushSettingsRow: View {

    @StateObject private var vm = NotificationSettingsViewModel()
    @EnvironmentObject private var modalC: ModalCoordinator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch vm.state {

            // ── 로딩 상태 ─────────────────────────────────────
            case .idle, .loading:
                row {
                    ProgressView()
                }

            // ── 오류 상태 ─────────────────────────────────────
            case .failed(let err):
                row {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(.red)
                }
                .contentShape(Rectangle()) // 전체 영역 탭
                .onTapGesture {
                    modalC.showToast(ToastItem(message: err.localizedDescription))
                    vm.refresh()
                }

            // ── 정상 상태 ─────────────────────────────────────
            case .loaded(let enabled):
                row {
                    if enabled {
                        // ‘끄기’ → 설정 앱
                        linkButton(title: "끄기", color: .red) {
                            openSettings()
                        }
                    } else {
                        // ‘켜기’ → 권한 요청 or 설정 앱
                        linkButton(title: "켜기",
                                   color: Color("PrimaryGradientEnd")) {

                            UNUserNotificationCenter.current()
                                .getNotificationSettings { settings in
                                    DispatchQueue.main.async {
                                        if settings.authorizationStatus == .notDetermined {
                                            // 첫 요청
                                            vm.requestPermission { granted in
                                                if !granted {
                                                    modalC.showToast(
                                                      ToastItem(message: vm.disableMessage())
                                                    )
                                                }
                                                vm.refresh()
                                            }
                                        } else {
                                            // 이미 거부됨 → 설정 앱
                                            openSettings()
                                        }
                                    }
                                }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        // 앱이 포그라운드로 돌아오면 상태 재확인
        .onChange(of: scenePhase) { ph in if ph == .active { vm.refresh() } }
    }

    // MARK: – 작은 헬퍼들 ---------------------------------------------------
    @ViewBuilder
    private func row<Trailing: View>(@ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text("푸시 알림")
                .font(.subheadline.bold())
                .foregroundColor(Color("TextPrimary"))
            Spacer()
            trailing()
        }
    }

    private func linkButton(title: String,
                            color: Color,
                            action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.bold())
            .foregroundColor(color)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url)
        else { return }
        UIApplication.shared.open(url)
    }
}
