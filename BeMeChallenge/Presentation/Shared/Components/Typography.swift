import SwiftUI

/// 앱 전체에서 쓰이는 “섹션/메인 타이틀” 컴포넌트
struct TitleText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .semibold, design: .default))
            .foregroundColor(Color("TextPrimary"))
            .multilineTextAlignment(.center)
    }
}
