//
//  CheckboxToggleStyle.swift
//  BeMeChallenge
//
import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill"
                                                     : "square")
                    .font(.title3)
                    .foregroundColor(configuration.isOn ? .blue : .secondary)

                configuration.label
                    .foregroundColor(.primary)
            }
            .contentShape(Rectangle()) // 전체 영역 탭 가능
        }
        .buttonStyle(.plain)
    }
}
