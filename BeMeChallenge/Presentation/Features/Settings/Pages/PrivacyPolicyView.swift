//
//  Presentation/Features/Settings/Pages/PrivacyPolicyView.swift
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("""
                 여기에 개인정보 처리방침 내용이 들어갑니다.

                 • 앱은 사용자의 이메일, 닉네임, 프로필 사진을 수집하며 \
                   이는 사용자 식별과 서비스 제공에만 사용됩니다.

                 • 수집된 정보는 Firebase 인프라에 안전하게 저장되며 \
                   제3자와 공유되지 않습니다.

                 • 사용자는 언제든지 계정 삭제를 통해 개인정보 삭제를 요청할 수 있습니다.
                 """)
                .font(.body)
                .lineSpacing(4)
                .padding()
                .foregroundColor(Color("TextPrimary"))
        }
        .navigationTitle("개인정보 처리방침")
        .navigationBarTitleDisplayMode(.inline)
    }
}
