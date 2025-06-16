//
//  Presentation/Features/Settings/Pages/CommunityGuidelineView.swift
//

import SwiftUI

struct CommunityGuidelineView: View {
    var body: some View {
        List {

            // ── 헤더 ───────────────────────────────────────
            VStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .foregroundColor(Color("PrimaryGradientEnd"))
                    .padding(.top, 24)

                Text("커뮤니티 가이드라인")
                    .font(.title2).bold()
                    .foregroundColor(Color("TextPrimary"))

                Text("BeMe Challenge는 모든 사용자가 안전하고 즐겁게 순간을 공유할 수 있는 공간을 지향합니다.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color("BackgroundPrimary"))
            .listRowInsets(.init(top: 0, leading: 0, bottom: 12, trailing: 0))

            // ── 핵심 수칙 ─────────────────────────────────
            Section(header: Text("지켜주세요").foregroundColor(Color("TextPrimary"))) {
                GuidelineRow(num: 1, text: "사진에는 폭력·노골적 성적 행위·혐오·극단주의 등 부적절한 내용을 포함할 수 없습니다.")
                GuidelineRow(num: 2, text: "타인의 얼굴·개인정보·저작물을 무단으로 노출하거나 도용하지 마세요.")
                GuidelineRow(num: 3, text: "광고, 스팸, 음란성 콘텐츠 업로드는 금지됩니다.")
                GuidelineRow(num: 4, text: "비방·차별·혐오 발언 및 괴롭힘을 조장하는 내용은 허용되지 않습니다.")
                GuidelineRow(num: 5, text: "챌린지의 취지에 맞춰 ‘즉흥적이고 진솔한’ 사진을 업로드해 주세요.")
            }

            // ── 위반 시 조치 ─────────────────────────────
            Section(header: Text("위반 시 조치").foregroundColor(Color("TextPrimary"))) {
                Text("• 신고가 **10회 누적**되거나 자동 검수(SafeSearch)에서 부적절 판정을 받을 경우, 즉시 삭제됩니다.")
                    .font(.body)

                Text("• 반복 위반 시 계정이 일시·영구적으로 제한될 수 있습니다.")
                    .font(.body)
                    .lineSpacing(4)
                    .padding(.vertical, 4)
            }

            // ── 신고·문의 ────────────────────────────────
            Section(header: Text("신고 · 문의").foregroundColor(Color("TextPrimary"))) {
                Text("문제가 되는 콘텐츠를 발견하면 게시물 메뉴 ▶︎ **신고** 버튼을 눌러주세요. 빠르게 검토하겠습니다.")
                    .font(.body)
                    .lineSpacing(4)
                    .padding(.vertical, 4)

                NavigationLink {
                    ContactSupportView()
                } label: {
                    Text("문의하기")
                        .font(.headline)
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("가이드라인")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 번호가 붙은 가이드라인 셀
private struct GuidelineRow: View {
    let num: Int; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(num).")
                .font(.headline)
                .foregroundColor(Color("PrimaryGradientEnd"))
            Text(text)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}
