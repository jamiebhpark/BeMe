//  AuthWrappers.swift
//  BeMeChallenge
import SwiftUI

/// 로그인 화면 래퍼 – 이미 생성된 AuthViewModel을 환경에서 받아 LoginView에 주입
struct LoginViewWrapper: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    var body: some View {
        LoginView()          // 추가 파라미터 필요 없음
    }
}

/// 온보딩 화면 래퍼 – 종료 시 플래그 저장
struct OnboardingViewWrapper: View {
    var body: some View {
        OnboardingView()
            .onDisappear {
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            }
    }
}
