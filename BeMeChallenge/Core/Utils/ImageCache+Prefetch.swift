//
//  ImageCache+Prefetch.swift
//  BeMeChallenge
//
import UIKit

extension ImageCache {
    /// 최대 `limit`장 선 다운로드해 캐시에 저장
    static func prefetch(urls: [URL], limit: Int = 4) {
        guard limit > 0 else { return }
        Task.detached(priority: .utility) {
            for url in urls.prefix(limit)
            where ImageCache.shared.image(for: url) == nil {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let img = UIImage(data: data) {
                        ImageCache.shared.store(img, for: url)
                    }
                } catch { /* ignore error */ }
            }
        }
    }
}
