//
//  CheckboxToggleStyle.swift
//  BeMeChallenge
//

import SwiftUI

/// 체크박스를 ‘팔레트 색 + 전체 영역 탭’으로 구현한 ToggleStyle
struct CheckboxToggleStyle: ToggleStyle {

    /// theme color 한곳에서만 바꿀 수 있게 상수화
    private let onColor  = Color("PrimaryGradientEnd")   // ✅ 팔레트
    private let offColor = Color.secondary

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn
                                   ? "checkmark.square.fill"
                                   : "square")
                    .font(.title3)
                    .foregroundColor(configuration.isOn ? onColor : offColor)

                configuration.label
                    .foregroundColor(Color("TextPrimary"))
            }
            .contentShape(Rectangle()) // 전체 영역 탭 가능
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
    }
}
