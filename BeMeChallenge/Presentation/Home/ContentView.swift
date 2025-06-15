//
//  ContentView.swift
//  BeMeChallenge
//

import SwiftUI

struct ContentView: View {
    // 전역에서 주입된 AuthViewModel 사용
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isLoggedIn {
                MainTabView()               // 홈 · 프로필 탭
            } else {
                LoginView()                 // 매개변수 필요 없음
            }
        }
        .onAppear {
            authViewModel.checkLoginStatus()
        }
    }
}
