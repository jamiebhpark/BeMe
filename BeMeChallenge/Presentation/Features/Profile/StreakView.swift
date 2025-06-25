//
//  StreakView.swift
//  BeMeChallenge
//
//  v2 — Warm-Streak 디자인 (“🔥 7일 연속!” 배지 스타일)
//

import SwiftUI

/// 프로필 화면 상단 ‘연속 참여’ 하이라이트 카드
struct StreakView: View {

    /// **총** 챌린지 참여 횟수 (ex: 42회)
    let totalParticipations: Int

    /// **연속** 참여 일수 (ex: 7일, 0이면 표시 X)
    let streakDays: Int

    /// 남은 Grace-Day 수 (2 → “Grace 2” 라벨)
    let graceLeft: Int

    // 메인 그라데이션 (앱 전역 팔레트 사용)
    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color("PrimaryGradientStart"), Color("PrimaryGradientEnd")],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(spacing: 16) {

            // ───────── Warm-Streak 배지 ─────────
            if streakDays > 0 {
                HStack(spacing: 8) {
                    Text("🔥")
                        .font(.title2)

                    Text("\(streakDays)일 연속!")
                        .font(.headline.weight(.semibold))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(gradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }

            // ───────── 통계 2열 ─────────
            HStack(spacing: 0) {

                // (1) 총 참여수
                VStack(spacing: 4) {
                    Text("총 참여")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(totalParticipations)회")
                        .font(.title3.weight(.bold))
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 44)

                // (2) Grace-Day 남은 횟수
                VStack(spacing: 4) {
                    Text("Grace")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(graceLeft)일")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(gradient)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
