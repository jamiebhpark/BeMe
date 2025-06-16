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
                     사용자의 개인정보는 Firebase를 통해 안전하게 보호되며, \
                     제3자와 공유되지 않습니다.
                     """)
                    .font(.body)
                    .lineSpacing(4)
                    .padding(.vertical, 4)

                Button("개인정보 처리방침 보기") {
                    if let url = URL(string: "https://bemechallenge.com/privacy") {
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
