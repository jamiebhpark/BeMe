import SwiftUI

struct HomeView: View {
    @StateObject private var vm   = ChallengeViewModel()
    @StateObject private var camC = CameraCoordinator()

    @State private var selectedType: ChallengeType = .mandatory   // 필수·오픈 필터

    var body: some View {
        VStack(spacing: 0) {

            // ── 세그먼트 ---------------------------------------------------
            Picker("챌린지 타입", selection: $selectedType) {
                Text(ChallengeType.mandatory.rawValue).tag(ChallengeType.mandatory)
                Text(ChallengeType.open.rawValue)     .tag(ChallengeType.open)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // ── 리스트 -----------------------------------------------------
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {

                    // 진행 중
                    if !vm.active.filter({ $0.type == selectedType }).isEmpty {
                        SectionHeader(title: "진행 중")

                        ForEach(vm.active.filter { $0.type == selectedType }) { ch in
                            ChallengeCardView(challenge: ch, viewModel: vm)
                                .environmentObject(camC)
                                .padding(.horizontal, 8)
                        }
                    }

                    // 종료 (7일 열람)
                    if !vm.closed.filter({ $0.type == selectedType }).isEmpty {
                        SectionHeader(title: "종료 • 7일 열람")

                        ForEach(vm.closed.filter { $0.type == selectedType }) { ch in
                            ChallengeCardView(challenge: ch, viewModel: vm)
                                .environmentObject(camC)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("챌린지")
        .background(Color("BackgroundPrimary").ignoresSafeArea())

        // ── 카메라 모달 ---------------------------------------------------
        .fullScreenCover(item: $camC.current) { ctx in
            CameraView(
                challengeId:    ctx.challengeId,
                participationId: ctx.participationId,
                onFinish:       { camC.dismiss() }
            )
        }
    }
}
