// Utils/ReloadableAsyncCachedImage.swift
import SwiftUI

/// A wrapper around AsyncCachedImage that reloads whenever the URL changes
struct ReloadableAsyncCachedImage<Content: View,
                                  Placeholder: View,
                                  Failure: View>: View {
    let url: URL?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var failure: () -> Failure

    var body: some View {
        AsyncCachedImage(url: url,
                         content: content,
                         placeholder: placeholder,
                         failure: failure)
            .id(url)
    }
}

// Convenience init for common case
extension ReloadableAsyncCachedImage
where Placeholder == ProgressView<EmptyView, EmptyView>, Failure == Image {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.content = content
        self.placeholder = { ProgressView() }
        self.failure = { Image(systemName: "photo") }
    }
}
