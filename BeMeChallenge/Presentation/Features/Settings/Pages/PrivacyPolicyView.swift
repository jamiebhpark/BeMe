// Presentation/Views/PrivacyPolicyView.swift
import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("""
                여기에 개인정보 처리방침 내용이 들어갑니다.
                사용자의 개인정보 수집, 이용, 보관 및 파기에 대한 자세한 정보를 제공해 주세요.
                예시: 본 앱은 사용자의 이메일, 닉네임 및 프로필 사진을 수집하며, 이 정보는 사용자 식별과 서비스 제공에 사용됩니다.
                ...
                """)
            .padding()
        }
        .navigationTitle("개인정보 처리방침")
    }
}
