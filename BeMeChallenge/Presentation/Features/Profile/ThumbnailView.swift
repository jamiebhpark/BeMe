//
//  Presentation/Features/Profile/ThumbnailView.swift
//

import SwiftUI

struct ThumbnailView: View {
    let url: URL?
    private let placeholder = Color(.systemGray5)

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    (phase.image ?? Image(systemName: "photo"))
                        .resizable()
                        .scaledToFill()
                }
            } else {
                placeholder
            }
        }
        .frame(height: 100)
        .clipped()
        .cornerRadius(4)
    }
}
