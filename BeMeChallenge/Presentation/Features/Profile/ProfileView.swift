//
//  Presentation/Features/Profile/ProfileView.swift
//  BeMeChallenge
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var vm       = ProfileViewModel()
    @StateObject private var streakVM = StreakViewModel()

    var body: some View {
        NavigationStack {
            viewForState(vm.profileState)
                .background(Color("BackgroundPrimary").ignoresSafeArea())
                .onAppear { streakVM.fetchAndCalculateStreak() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsRootView()
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3)
                                .foregroundColor(Color("TextPrimary"))
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func viewForState(_ state: Loadable<UserProfile>) -> some View {
        switch state {
        case .idle, .loading:
            ProgressView()
                .frame(maxHeight: .infinity)

        case .failed(let err):
            VStack(spacing: 16) {
                Text("로드 실패: \(err.localizedDescription)")
                Button("재시도") {
                    vm.refresh()
                }
                .buttonStyle(.bordered)
            }
            .padding()

        case .loaded(let profile):
            LoadedContent(
                profile:       profile,
                posts:         vm.userPosts,
                streakDays:    streakVM.streakDays,
                graceLeft:     streakVM.graceLeft,
                refreshStreak: { streakVM.fetchAndCalculateStreak() },
                profileVM:     vm
            )
        }
    }
}


// MARK: – LoadedContent -------------------------------
private struct LoadedContent: View {
    let profile: UserProfile
    let posts:   [Post]
    let streakDays: Int
    let graceLeft:  Int
    let refreshStreak: () -> Void

    // DI 받은 vm은 @ObservedObject로 감싸 줍니다
    @ObservedObject var profileVM: ProfileViewModel

    // 명시적 init으로 wrapper를 초기화해야 property-wrapper 타입 혼선을 피할 수 있습니다
    init(
        profile: UserProfile,
        posts: [Post],
        streakDays: Int,
        graceLeft: Int,
        refreshStreak: @escaping () -> Void,
        profileVM: ProfileViewModel
    ) {
        self.profile   = profile
        self.posts     = posts
        self.streakDays   = streakDays
        self.graceLeft    = graceLeft
        self.refreshStreak = refreshStreak
        _profileVM = ObservedObject(wrappedValue: profileVM)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ① 프로필 헤더
                ProfileHeaderView(profile: profile) {
                    NavigationLink {
                        ProfileEditView(vm: profileVM)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.title3)
                    }
                }
                .padding(.horizontal)

                // ② Warm-Streak 카드
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "연속 참여")
                    StreakView(
                        totalParticipations: posts.count,
                        streakDays:          streakDays,
                        graceLeft:           graceLeft
                    )
                    .padding(.horizontal)
                }
                .cardStyle()

                // ③ 챌린지 제안 요약 카드
                ChallengeIdeaSection {
                    ChallengeIdeasListView()
                }
                .padding(.vertical)
            }
        }
    }
}
