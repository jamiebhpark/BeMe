//
//  SelectableHighlight.swift
//  BeMeChallenge
//
//  셀을 “선택”했을 때 옅은 배경으로 강조해 주는 심플 modifier
//

import SwiftUI

private struct SelectableHighlight: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                isSelected
                ? Color.accentColor.opacity(0.12)
                : Color.clear
            )
    }
}

extension View {
    /// 선택 상태에 따라 셀 배경을 하이라이트합니다.
    @inline(__always)
    func selectable(_ isSelected: Bool) -> some View {
        self.modifier(SelectableHighlight(isSelected: isSelected))
    }
}
