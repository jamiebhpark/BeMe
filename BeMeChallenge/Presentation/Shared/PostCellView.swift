//
//  Presentation/Shared/PostCellView.swift
//  BeMeChallenge
//

import SwiftUI
import FirebaseAuth
import UIKit   // UIActivityViewController (현재 미사용)

/// 피드 카드 셀
struct PostCellView: View {

    // MARK: – Props --------------------------------------------------------
    let post:  Post
    let user:  User?
    var onLike:   () -> Void = {}
    var onReport: () -> Void = {}
    var onDelete: () -> Void = {}
    var showActions: Bool    = true

    // MARK: – Local State --------------------------------------------------
    @State private var showHeart      = false
    @State private var heartScale:  CGFloat = 0.1
    @State private var heartOpacity: Double  = 0.0

    @EnvironmentObject private var modalC: ModalCoordinator

    // MARK: – Computed -----------------------------------------------------
    private var likeCount: Int { post.reactions["❤️", default: 0] }
    private var isLiked: Bool  { likeCount > 0 }

    // MARK: – Body ---------------------------------------------------------
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
        .alert(item: $modalC.modalAlert, content: buildAlert)
    }

    // MARK: – Header -------------------------------------------------------
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

    // MARK: – Image --------------------------------------------------------
    private var imageSection: some View {
        ZStack {
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
        }
    }

    // MARK: – Action Bar ---------------------------------------------------
    private var actionBar: some View {
        HStack {
            Button(action: animateLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(Color("Lavender"))
            }
            Spacer()
        }
        .padding(8)
    }

    // MARK: – Footer -------------------------------------------------------
    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(likeCount)명이 좋아합니다")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color("Lavender"))

            if let caption = post.caption, !caption.isEmpty {
                (Text(displayName).bold() + Text(" \(caption)"))
                    .font(.subheadline)
                    .foregroundColor(Color("TextPrimary"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.horizontal, .bottom], 8)
    }

    // MARK: – Helpers ------------------------------------------------------
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy.MM.dd · HH:mm"
        return df
    }()

    private var displayName: String {
        let raw = user?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "익명" : raw
    }

    private var avatar: some View {
        Group {
            if let url = user?.effectiveProfileImageURL {
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

    // MARK: – Like Logic & Animation --------------------------------------
    private func animateLike() {
        onLike()                               // ViewModel에 Optimistic 요청
        heartScale = 0.2; heartOpacity = 1; showHeart = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            heartScale = 1.1
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            heartOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showHeart = false
        }
    }

    // MARK: – Alert Builder ------------------------------------------------
    private func buildAlert(for alert: ModalAlert) -> Alert {
        switch alert {
        case .manage(let p):
            return Alert(
                title: Text("게시물 관리"),
                primaryButton: .destructive(Text("삭제")) {
                    onDelete()
                    DispatchQueue.main.async {
                        modalC.resetAlert()
                        modalC.showToast(.init(message: "삭제 완료"))
                    }
                },
                secondaryButton: .destructive(Text("신고")) {
                    onReport()
                }
            )

        case .deleteConfirm, .reportConfirm:
            return Alert(title: Text("알림"))
        }
    }
}
