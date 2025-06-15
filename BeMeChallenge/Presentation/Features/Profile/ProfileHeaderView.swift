// Presentation/Features/Profile/ProfileHeaderView.swift
import SwiftUI

struct ProfileHeaderView<Content: View>: View {
    let profile: UserProfile
    let actionContent: () -> Content

    init(profile: UserProfile,
         @ViewBuilder actionContent: @escaping () -> Content)
    {
        self.profile = profile
        self.actionContent = actionContent
    }

    private var avatarURL: URL? {
        profile.effectiveProfileImageURL
    }


    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("PrimaryGradientStart"), Color("PrimaryGradientEnd")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

            Rectangle()
                .fill(.ultraThinMaterial)
                .cornerRadius(16)

            HStack(spacing: 16) {
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.nickname)
                        .font(.title2).bold()
                        .foregroundColor(.white)
                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                Spacer()

                actionContent()
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
}
