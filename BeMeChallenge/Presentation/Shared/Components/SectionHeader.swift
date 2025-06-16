//
//  SectionHeader.swift
//  BeMeChallenge
//

import SwiftUI

/// 카드·리스트 안에서 쓰는 단일 행 헤더
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline.weight(.semibold)) // Dynamic Type 대응
            .foregroundColor(.primary)         // 시스템 기본 색상 (라이트/다크 자동)
            .padding(.horizontal)
            .padding(.top, 4)                  // 카드 상단과 살짝 간격
    }
}
