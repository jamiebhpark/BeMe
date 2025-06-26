//
//  View+CardStyle.swift
//  BeMeChallenge
//
//  공통 카드 스타일 Modifier
//

import SwiftUI

extension View {
    /// 앱 전역 카드 꾸밈 (배경·코너·그림자·가로 패딩)
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal)
    }
}
