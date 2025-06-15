// AboutView.swift
import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        List {
            // 로고 & 앱 이름
            VStack(spacing: 8) {
                Image("appLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding(.top, 16)
                Text("BeMe Challenge")
                    .font(.title2).bold()
                Text("Version \(appVersion)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color(.systemGroupedBackground))
            .listRowInsets(.init(top: 0, leading: 0, bottom: 8, trailing: 0))
            
            // 앱 소개 섹션
            Section(header: Text("앱 소개")) {
                Text("""
                BeMe Challenge는 필터 없는 진정성 있는 순간을 공유하는 SNS입니다. \
                실시간 챌린지를 통해 챌린저들과 더 가까워질 수 있어요.
                """)
                  .font(.body)
                  .lineSpacing(4)
                  .padding(.vertical, 4)
            }
            
            // 개인정보 처리방침 섹션
            Section(header: Text("개인정보 처리방침")) {
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
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.vertical, 8)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}
