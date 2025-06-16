//
//  Presentation/Features/Profile/ProfileHeaderView.swift
//

import SwiftUI

struct ProfileHeaderView<Content: View>: View {
    let profile: UserProfile
    let actionContent: () -> Content

    init(profile: UserProfile,
         @ViewBuilder actionContent: @escaping () -> Content) {
        self.profile = profile
        self.actionContent = actionContent
    }

    private var avatarURL: URL? { profile.effectiveProfileImageURL }

    // ───────────────────────────────────────────────────────── View
    var body: some View {
        ZStack {

            // ① 백그라운드 그라디언트
            LinearGradient(
                colors: [Color("PrimaryGradientStart"), Color("PrimaryGradientEnd")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

            // ② 블러 코팅
            Rectangle()
                .fill(.ultraThinMaterial)
                .cornerRadius(16)

            // ③ 실제 콘텐츠
            HStack(spacing: 16) {

                // 아바타
                Group {
                    if let url = avatarURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:   ProgressView()
                            case .failure: Image("defaultAvatar").resizable()
                            case .success(let img): img.resizable().scaledToFill()
                            @unknown default: EmptyView()
                            }
                        }
                    } else {
                        Image("defaultAvatar").resizable()
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))

                // 닉네임 · Bio
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.nickname)
                        .font(.title2).bold()
                        .foregroundColor(.white)

                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }
                }

                Spacer()

                // 우측 액션들 (예: 편집 버튼)
                actionContent()
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
}
