//
//  Presentation/Home/OnboardingView.swift
//
import SwiftUI

// MARK: - 데이터 모델
struct OnboardingPage: Identifiable {
    var id = UUID()
    var imageName: String
    var title: String
    var description: String
}

// MARK: - 온보딩 메인
struct OnboardingView: View {

    // ───────── 상태 ─────────
    @State private var currentPage = 0
    @State private var agreed      = false   // 가이드라인 동의

    // ───────── 인트로 페이지 ─────────
    private let introPages: [OnboardingPage] = [
        .init(imageName: "onboarding1", title: "진정성 있는 순간",
              description: "광고 없는 순수한 일상을 공유합니다."),
        .init(imageName: "onboarding2", title: "즉석 촬영",
              description: "필터 없이, 있는 그대로의 당신을 기록하세요."),
        .init(imageName: "onboarding3", title: "특별한 챌린지",
              description: "참여해야만 볼 수 있는 특별한 챌린지에 도전하세요.")
    ]
    private var pageCount: Int { introPages.count + 1 }

    // 버튼 그라데이션
    private var buttonGradient: LinearGradient {
        LinearGradient(colors: [Color("PrimaryGradientStart"),
                                Color("PrimaryGradientEnd")],
                       startPoint: .leading, endPoint: .trailing)
    }

    // ───────── 본문 ─────────
    var body: some View {
        ZStack(alignment: .bottom) {
            // ① 인트로 & 가이드라인 페이지
            TabView(selection: $currentPage) {
                ForEach(introPages.indices, id: \.self) { idx in
                    OnboardingIntroPage(page: introPages[idx])
                        .tag(idx)
                }
                GuidelinePage(agreed: $agreed)
                    .tag(pageCount - 1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .ignoresSafeArea()

            // ② “시작하기” 버튼 (가이드라인 페이지에서만)
            if currentPage == pageCount - 1 {
                Button(action: completeOnboarding) {
                    Text("시작하기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .disabled(!agreed)
                .foregroundColor(.white)
                .background(
                    (agreed ? AnyView(buttonGradient)
                            : AnyView(Color.gray.opacity(0.3)))
                    .ignoresSafeArea(edges: .bottom)   // 하단 흰띠 제거
                )
            }
        }
        .onAppear(perform: redirectIfNeeded)
    }

    // MARK: - 온보딩 완료 처리
    private func completeOnboarding() {
        guard agreed else { return }
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        UserDefaults.standard.set(true, forKey: "agreedGuideline")
        // TODO: 코디네이터 / AppState 등을 통해 홈 화면 전환
    }

    private func redirectIfNeeded() {
        if UserDefaults.standard.bool(forKey: "hasSeenOnboarding"),
           UserDefaults.standard.bool(forKey: "agreedGuideline") {
            completeOnboarding()
        }
    }
}
