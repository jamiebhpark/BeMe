//
//  PostCellView.swift
//  BeMeChallenge
//

import SwiftUI
import FirebaseAuth
import UIKit   // UIActivityViewController (공유 기능은 잠시 미사용)

/// 포스트 카드 셀
struct PostCellView: View {
    // MARK: - Props
    let post: Post
    let user: User?
    var onLike:   () -> Void = {}
    var onReport: () -> Void = {}
    var onDelete: () -> Void = {}
    var showActions: Bool = true
    
    // MARK: - State
    @State private var showHeart      = false
    @State private var heartScale: CGFloat  = 0.1
    @State private var heartOpacity: Double = 0.0
    @State private var localReactions: [String:Int]   // Optimistic like
    
    @EnvironmentObject private var modalC: ModalCoordinator
    
    // MARK: - Init
    init(post: Post,
         user: User?,
         onLike: @escaping ()->Void = {},
         onReport: @escaping ()->Void = {},
         onDelete: @escaping ()->Void = {},
         showActions: Bool = true)
    {
        self.post = post
        self.user = user
        self.onLike = onLike
        self.onReport = onReport
        self.onDelete = onDelete
        self.showActions = showActions
        _localReactions = State(initialValue: post.reactions)
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 12) {
            header
            imageSection
            if showActions { actionBar }
            footer
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        // 그림자 제거로 보다 플랫한 느낌
        //.shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
        .alert(item: $modalC.modalAlert, content: buildAlert)
    }
    
    // MARK: Header (Avatar · Nick · 날짜+시간 · 메뉴)
    private var header: some View {
        HStack(spacing: 12) {
            avatar
            Text(displayName).font(.subheadline.bold())
            Spacer()
            Text(post.createdAt, formatter: Self.dateFormatter)
                .font(.caption).foregroundColor(.secondary)
            
            if showActions {
                Button { modalC.showAlert(.manage(post: post)) } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .padding(.horizontal, 4)
                }
            }
        }
        .padding([.horizontal, .top], 12)
    }
    
    // MARK: Image
    private var imageSection: some View {
        ZStack {
            AsyncCachedImage(
                url: URL(string: post.imageUrl),
                content: { $0.resizable().scaledToFill() },
                placeholder: { ProgressView() },
                failure:     { Color(.systemGray5) }
            )
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
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
    
    // MARK: Action Bar (Like만 남김)
    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                let key = "❤️"
                let isLiked = (localReactions[key] ?? 0) > 0
                localReactions[key] =
                    (localReactions[key] ?? 0) + (isLiked ? -1 : 1)
                onLike()
            } label: {
                Image(systemName: (localReactions["❤️"] ?? 0) > 0 ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            Spacer()
            // 공유 버튼은 기능 준비 전이므로 숨김
        }
        .padding(4)
    }
    
    // MARK: Footer (Leading 정렬)
    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(localReactions["❤️", default: 0])명이 좋아합니다")
                .font(.subheadline.bold())
            if let caption = post.caption, !caption.isEmpty {
                (Text(displayName).bold() + Text(" \(caption)"))
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.horizontal, .bottom], 8)
    }
    
    // MARK: - Helpers
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd · HH:mm"
        f.locale     = .current
        return f
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
                .id(url)     // URL 바뀌면 리로드
            } else {
                Image("defaultAvatar").resizable()
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }
    
    // MARK: Alert builder
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
                  onReport()          // ✅ 이것만 호출
              }
            )
        case .deleteConfirm, .reportConfirm:
            return Alert(title: Text("알림"))
        }
    }
    
    // MARK: Like 애니
    private func animateLike() {
        let key = "❤️"
        let isLiked = (localReactions[key] ?? 0) > 0
        localReactions[key] =
            (localReactions[key] ?? 0) + (isLiked ? -1 : 1)
        onLike()
        
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
}
