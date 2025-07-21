//
//  OnboardingView.swift
//  BeMeChallenge
//

import SwiftUI

// ───────── 데이터 모델 ─────────
struct OnboardingPage: Identifiable {
    var id = UUID()
    var imageName: String
    var title: String
    var description: String
}
struct OnboardingView: View {

    @State private var currentPage = 0
    @State private var agreed      = false

    @AppStorage("hasSeenOnboarding")  private var hasSeen = false
    @AppStorage("agreedGuideline")    private var agreedGd = false

    private let introPages: [OnboardingPage] = [
        .init(imageName: "onboarding1", title: "진정성 있는 순간",   description: "광고 없는 순수한 일상을 공유합니다."),
        .init(imageName: "onboarding2", title: "즉석 촬영",         description: "필터 없이, 있는 그대로의 당신을 기록하세요."),
        .init(imageName: "onboarding3", title: "특별한 챌린지",     description: "참여해야만 볼 수 있는 특별한 챌린지에 도전하세요.")
    ]
    private var pageCount: Int { introPages.count + 1 }

    private var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [Color("PrimaryGradientStart"), Color("PrimaryGradientEnd")],
            startPoint: .leading, endPoint: .trailing
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // ─── 배경 이미지 ───
            Group {
                if currentPage < introPages.count {
                    // 1·2·3 페이지
                    Image(introPages[currentPage].imageName)
                        .resizable()
                        .scaledToFill()
                        .offset(x: -30)
                } else {
                    // 마지막 GuidelinePage 배경
                    Image("onboarding_guideline")
                        .resizable()
                        .scaledToFill()
                        .offset(x: -30)

                }
            }
            .ignoresSafeArea()  // 화면 최상단부터 홈 인디케이터 자리까지
            .animation(.easeInOut(duration: 0.4), value: currentPage)

            // ─── 컨텐츠 탭 ───
            TabView(selection: $currentPage) {
                ForEach(introPages.indices, id: \.self) { idx in
                    OnboardingIntroPage(page: introPages[idx])
                        .tag(idx)
                }
                GuidelinePage(agreed: $agreed)
                    .tag(pageCount - 1)
                // **이제 GuidelinePage 내부에 배경이 없으니,
                // Safe-Area 처리는 모두 위 이미지가 담당합니다.**
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            // ─── 시작하기 버튼 ───
            if currentPage == pageCount - 1 {
                Button("시작하기", action: finish)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        (agreed ? buttonGradient
                                : LinearGradient(colors: [.gray.opacity(0.3)],
                                                 startPoint: .top, endPoint: .bottom))
                        .ignoresSafeArea(edges: .bottom)
                    )
                    .foregroundColor(.white)
                    .disabled(!agreed)
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .onAppear { fastForwardIfNeeded() }
    }

    private func finish() {
        guard agreed else { return }
        hasSeen = true
        agreedGd = true
    }

    private func fastForwardIfNeeded() {
        if hasSeen && agreedGd {
            currentPage = pageCount - 1
            agreed = true
            finish()
        }
    }
}
