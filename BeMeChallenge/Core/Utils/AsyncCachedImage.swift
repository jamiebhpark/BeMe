//AsyncCachedImage.swift
import SwiftUI

struct AsyncCachedImage<Content: View,
                        Placeholder: View,
                        Failure: View>: View {

    let url: URL?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var failure: () -> Failure

    @State private var phase: Phase = .empty

    var body: some View {
        // URL이 바뀌면 phase를 .empty로 리셋
        Group {
            switch phase {
            case .success(let img):
                content(Image(uiImage: img))
            case .failure:
                failure()
            case .empty:
                placeholder()
                    .task { await load() }
            }
        }
        .onChange(of: url) { _, _ in          // ← 두 파라미터 클로저
            phase = .empty
        }
    }

    private func load() async {
        guard let url = url, case .empty = phase else { return }
        if let cached = ImageCache.shared.image(for: url) {
            phase = .success(cached); return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let img = UIImage(data: data) else {
                phase = .failure; return
            }
            ImageCache.shared.store(img, for: url)
            phase = .success(img)
        } catch {
            phase = .failure
        }
    }

    private enum Phase {
        case empty
        case success(UIImage)
        case failure
    }
}

extension AsyncCachedImage
where Placeholder == ProgressView<EmptyView, EmptyView>,
      Failure == Image {

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.content = content
        self.placeholder = { ProgressView() }
        self.failure = { Image(systemName: "photo") }
    }
}
