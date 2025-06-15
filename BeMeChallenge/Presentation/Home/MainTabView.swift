// Presentation/Home/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // ─── 홈 탭 ───
            NavigationStack {
                HomeView()
                    .navigationTitle("챌린지")
                    .navigationBarTitleDisplayMode(.inline)
                    // value-based 대신 직접 link
            }
            .tabItem {
                Label("홈", systemImage: "house.fill")
            }

            // ─── 프로필 탭 ───
            NavigationStack {
                ProfileView()
                    .navigationTitle("프로필")
                    .navigationBarTitleDisplayMode(.inline)
                    // 톱니바퀴 toolbar는 ProfileView 내부에 정의
            }
            .tabItem {
                Label("프로필", systemImage: "person.crop.circle")
            }
        }
        .accentColor(Color("PrimaryGradientEnd"))
    }
}
