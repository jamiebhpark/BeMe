//
//  ProfileView.swift
//
import SwiftUI

struct ProfileView: View {
    @StateObject private var vm       = ProfileViewModel()
    @StateObject private var streakVM = StreakViewModel()

    var body: some View {
        Group {
            switch vm.profileState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxHeight: .infinity)

            case .failed(let err):
                VStack(spacing: 16) {
                    Text("로드 실패: \(err.localizedDescription)")
                    Button("재시도") { vm.refresh() }
                }
                .padding()

            case .loaded(let profile):
                ProfileLoadedContent(
                    profile: profile,
                    posts: vm.userPosts,
                    streakDays: streakVM.currentStreak,
                    refreshStreak: streakVM.fetchAndCalculateStreak,
                    profileVM: vm
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsRootView() } label: {
                    Image(systemName: "gearshape").font(.title3)
                }
            }
        }
        .onAppear { vm.refresh() }
    }
}

// MARK: - 분리한 Sub-View
fileprivate struct ProfileLoadedContent: View {
    let profile: UserProfile
    let posts:   [Post]
    let streakDays: Int
    let refreshStreak: () -> Void
    @ObservedObject var profileVM: ProfileViewModel

    private let grid = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── 헤더
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

                // ── Streak
                VStack(alignment: .leading, spacing: 12) {
                    Text("연속 참여").font(.headline).padding(.horizontal)
                    StreakView(
                        totalParticipations: posts.count,
                        streakDays: streakDays
                    )
                    .padding()
                }
                .cardStyle()

                // ── 내 포스트
                VStack(alignment: .leading, spacing: 12) {
                    Text("내 포스트").font(.headline).padding(.horizontal)
                    LazyVGrid(columns: grid, spacing: 4) {
                        ForEach(posts) { post in          // ✅ Identifiable
                            NavigationLink {
                                ProfileFeedView(
                                    profileVM: profileVM,
                                )
                            } label: {
                                ThumbnailView(url: URL(string: post.imageUrl))
                            }
                        }
                    }
                    .padding([.horizontal, .bottom])
                }
                .cardStyle()
            }
            .padding(.vertical)
        }
        .onAppear(perform: refreshStreak)
    }
}

// MARK: - 카드 공통 데코레이터
fileprivate extension View {
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal)
    }
}
