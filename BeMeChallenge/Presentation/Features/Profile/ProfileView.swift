//
//  ProfileView.swift
//  BeMeChallenge
//
//  v2 — Warm-Streak 카드 + Grace day 표시
//

import SwiftUI

struct ProfileView: View {

    @StateObject private var vm       = ProfileViewModel()
    @StateObject private var streakVM = StreakViewModel()

    var body: some View {
        NavigationStack {                      // ← 네비게이션 스택 래핑
            Group {                            // ← switch 결과를 하나의 View 로 묶음
                switch vm.profileState {

                case .idle, .loading:
                    ProgressView().frame(maxHeight: .infinity)

                case .failed(let err):
                    VStack(spacing: 16) {
                        Text("로드 실패: \(err.localizedDescription)")
                        Button("재시도") { vm.refresh() }
                    }
                    .padding()

                case .loaded(let profile):
                    LoadedContent(
                        profile:    profile,
                        posts:      vm.userPosts,
                        streakDays: streakVM.streakDays,
                        graceLeft:  streakVM.graceLeft,
                        refreshStreak: { streakVM.fetchAndCalculateStreak() },
                        profileVM:  vm
                    )
                }
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .onAppear {
                streakVM.fetchAndCalculateStreak()
            }
            .toolbar {                         // ← 이제 정상 부착
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
}

// MARK: – 프로필 로드 성공 시 메인 컨텐츠 -------------------------------
private struct LoadedContent: View {

    let profile: UserProfile
    let posts:   [Post]

    let streakDays:    Int
    let graceLeft:     Int
    let refreshStreak: () -> Void

    @ObservedObject var profileVM: ProfileViewModel

    private let grid = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // ── 프로필 헤더 ───────────────────────────
                ProfileHeaderView(profile: profile) {
                    NavigationLink {
                        ProfileEditView(vm: profileVM)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                
                // ── Warm-Streak 카드 ────────────────────
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
            }
        }
    }
}

// MARK: – 카드 데코레이터 ----------------------------------------------
private extension View {
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(16)
            // ⬇️ 수정:  .opacity(0.05)  ← 괄호 호출
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal)
    }
}
