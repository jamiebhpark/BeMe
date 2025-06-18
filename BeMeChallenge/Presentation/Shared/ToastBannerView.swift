//  ToastBannerView.swift
//  BeMeChallenge
//
//  상단 토스트 배너 – 감성적 미니멀리즘 & 직관성 컨셉
//  디자인 가이드: 파스텔 그라데이션(라벤더 → 하늘색), 캡슐형, 그림자, Dynamic Type 대응
//
//  사용법:
//  WindowGroup 루트(.overlay) 에서
//      if let toast = modalC.toast {
//         ToastBannerView(toast: toast)
//              .transition(.move(edge: .top).combined(with: .opacity))
//              .zIndex(1_000)
//      }
//
//  modalC.showToast(ToastItem(message: "…")) 로 호출하면 2.5초간 표시 후 자동 사라집니다.

import SwiftUI

struct ToastBannerView: View {
    // IN
    let toast: ToastItem
    
    // ENV
    @EnvironmentObject private var modalC: ModalCoordinator
    @Environment(\.dynamicTypeSize) private var dynSize
    
    // DESIGN TOKENS (Asset Catalog 컬러)
    private let gradientStart = Color("Lavender")   // #D8B4FE
    private let gradientEnd   = Color("SkyBlue")    // #93C5FD
    
    var body: some View {
        Text(toast.message)
            .font(.system(.subheadline, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                LinearGradient(colors: [gradientStart, gradientEnd],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
            .padding(.horizontal, 20)
            // 접근성: VoiceOver 라벨
            .accessibilityLabel(Text(toast.message))
            .onTapGesture {
                withAnimation { modalC.resetToast() }   // 탭으로 즉시 닫기
            }
            // 상태 바/노치 높이 고려하여 상단 safeArea 바로 아래 배치됨
    }
}
