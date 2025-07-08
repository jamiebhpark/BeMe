//
//  Presentation/Features/Settings/Pages/AboutView.swift
//

import SwiftUI

struct AboutView: View {

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        List {
            // ── 로고 & 앱 이름 ───────────────────────────────
            VStack(spacing: 8) {
                Image("appLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding(.top, 20)

                Text("BeMe Challenge")
                    .font(.title2).bold()
                    .foregroundColor(Color("TextPrimary"))

                Text("Version \(appVersion)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color("BackgroundPrimary"))
            .listRowInsets(.init(top: 0, leading: 0, bottom: 12, trailing: 0))

            // ── 앱 소개 ─────────────────────────────────────
            Section(header: Text("앱 소개").foregroundColor(Color("TextPrimary"))) {
                Text("""
                     BeMe Challenge는 필터 없는 진정성 있는 순간을 공유하는 SNS입니다. \
                     실시간 챌린지를 통해 챌린저들과 더 가까워질 수 있어요.
                     """)
                    .font(.body)
                    .lineSpacing(4)
                    .padding(.vertical, 4)
            }

            // ── 개인정보 처리방침 ──────────────────────────
            Section(header: Text("개인정보 처리방침").foregroundColor(Color("TextPrimary"))) {
                Text("""
                     • 앱은 사용자의 이메일, 닉네임, 프로필 사진을 수집하며 \
                       이는 사용자 식별과 서비스 제공에만 사용됩니다.

                     • 수집된 정보는 Firebase 인프라에 안전하게 저장되며 \
                       제3자와 공유되지 않습니다.
                     
                     • 챌린지 종료 후 +7일 후에 개인정보 보호를 위해 \
                       일괄적으로 앱 및 서버에서 삭제됩니다.

                     • 사용자는 언제든지 계정 삭제를 통해 개인정보 삭제를 요청할 수 있습니다.
                     """)
                    .font(.body)
                    .lineSpacing(4)
                    .padding(.vertical, 4)

                Button("개인정보 처리방침 보기") {
                    if let url = URL(string: "https://quilt-cover-7b9.notion.site/beme-app-privacy-policy") {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(GradientCapsule())
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("앱 정보")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 공통 Capsule + 그라디언트 버튼
private struct GradientCapsule: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(
                LinearGradient(colors: [Color("Lavender"), Color("SkyBlue")],
                               startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
