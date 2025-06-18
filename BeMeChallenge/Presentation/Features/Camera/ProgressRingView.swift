//
//  ProgressRingView.swift
//  BeMeChallenge
//

import SwiftUI

/// ⏱ 타이머 진행률 원형 프로그래스 (Lavender → Red)
struct ProgressRingView: View {
    /// 0 … 1  (1 = 시작, 0 = 완료)
    let progress: Double

    var body: some View {
        ZStack {
            // 배경 트랙
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 8)

            // 진행 스트로크
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color("Lavender"), .red               // ⬅️ asset 없다면 SwiftUI .red
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle:   .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 8,
                                       lineCap: .round,
                                       lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))           // 12 시 시작

            // 남은 초 텍스트
            Text("\(Int(ceil(progress * 60)))")
                .font(.headline).bold()
                .foregroundColor(.white)
        }
        .frame(width: 90, height: 90)
    }
}
