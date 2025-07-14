//
//  PostCellView.swift
//  BeMeChallenge
//
//  Updated: 2025-07-14 – 댓글 수 표시 + 연속 🔥 뱃지
//

import SwiftUI
import FirebaseAuth
import UIKit

/// 피드 카드 셀
struct PostCellView: View {

    // MARK: Props
    let post:  Post
    let user:  LiteUser?
    var onLike:   () -> Void = {}
    var onReport: () -> Void = {}
    var onDelete: () -> Void = {}
    var showActions: Bool    = true

    // MARK: State
    @State private var showHeart      = false
    @State private var heartScale:  CGFloat = 0.1
    @State private var heartOpacity: Double  = 0.0
    @State private var showComments   = false

    @EnvironmentObject private var modalC: ModalCoordinator

    // MARK: Computed
    private var likeCount: Int { post.reactions["❤️", default: 0] }
    private var isLiked  : Bool { likeCount > 0 }

    // MARK: Body
    var body: some View {
        VStack(spacing: 12) {
            header
            imageSection
            if showActions { actionBar }
            footer
        }
        .background(Color("SurfaceSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color("SurfaceBorder"), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showComments) {
            CommentsSheet(post: post)
                .environmentObject(modalC)
        }
    }

    // MARK: Header
    private var header: some View {
        HStack(spacing: 12) {
            avatar
            Text(displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color("TextPrimary"))
            Spacer()
            Text(post.createdAt, formatter: Self.dateFormatter)
                .font(.caption)
                .foregroundColor(.secondary)

            if showActions {
                Button { modalC.showAlert(.manage(post: post)) } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .padding(.horizontal, 4)
                        .foregroundColor(Color("TextPrimary"))
                }
            }
        }
        .padding([.horizontal, .top], 12)
    }

    // MARK: Image / Placeholder / Blocked
    @ViewBuilder
    private var imageSection: some View {
        switch post.rejected {
        case .some(true):   blockedView
        case nil:           pendingView
        case .some(false):  photoView      // ✅ 정상 이미지
        }
    }

    /// ⛔️ 차단 이미지
    private var blockedView: some View {
        VStack {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            Text("부적절한 이미지")
                .font(.subheadline).bold()
                .foregroundColor(.red)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// ⏳ 검사 중
    private var pendingView: some View {
        VStack {
            ProgressView("검수 중…")
                .progressViewStyle(.circular)
                .tint(.orange)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// ✅ 정상 이미지 + Like 애니메이션 + Streak 뱃지
    private var photoView: some View {
        ZStack(alignment: .topLeading) {
            AsyncCachedImage(
                url: URL(string: post.imageUrl),
                content: { $0.resizable().scaledToFill() },
                placeholder: { Color(.systemGray5) },
                failure:     { Color(.systemGray5) }
            )
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { animateLike() }

            if showHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 90))
                    .foregroundColor(.white)
                    .scaleEffect(heartScale)
                    .opacity(heartOpacity)
                    .shadow(radius: 10)
            }

            // 🔥 Streak Badge (2일 이상)
            if let n = post.streakNum, n > 0 {
                StreakBadgeView(count: n)
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
            }
            // 🏅 Open Count Badge (open 챌린지)
            else if let c = post.openCountNum, c > 0 {
                OpenCountBadgeView(count: c)
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: Like / Comment Bar
    private var actionBar: some View {
        HStack(spacing: 20) {
            // ❤️ Like
            Button(action: animateLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.title2)
            }
            .foregroundColor(Color("Lavender"))

            // 💬 Comment + count
            Button { showComments = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                    Text("\(post.commentsCount)")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundColor(Color("Lavender"))

            Spacer()

            Text("\(likeCount)명이 좋아합니다")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color("Lavender"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: Footer
    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let caption = post.caption, !caption.isEmpty {
                (Text(displayName).bold() + Text(" \(caption)"))
                    .font(.subheadline)
                    .foregroundColor(Color("TextPrimary"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.horizontal, .bottom], 8)
    }

    // MARK: Helpers
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "yyyy.MM.dd · HH:mm"; return df
    }()
    private var displayName: String {
        let raw = user?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "익명" : raw
    }
    private var avatar: some View {
        Group {
            if let url = user?.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:   ProgressView()
                    case .failure: Image("defaultAvatar").resizable()
                    case .success(let img): img.resizable().scaledToFill()
                    @unknown default: EmptyView()
                    }
                }
                .id(url)
            } else {
                Image("defaultAvatar").resizable()
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }

    // MARK: Like Animation
    private func animateLike() {
        DispatchQueue.main.async { onLike() }
        heartScale = 0.2; heartOpacity = 1; showHeart = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { heartScale = 1.1 }
        withAnimation(.easeOut(duration: 0.4).delay(0.4))           { heartOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8)       { showHeart = false }
    }
}
