//
//  ImageCache.swift
//  BeMeChallenge
//
//  • SHA-256 해시 파일명 → 충돌 방지
//  • 디스크 한도 100 MB  → 오래된 순 LRU 삭제
//  • 디스크 I/O 전부 background queue 처리
//

import UIKit
import CryptoKit               // ✅ 새로 필요

final class ImageCache {

    // MARK: - Singleton
    static let shared = ImageCache()
    private init() { }

    // MARK: - In-Memory (자동 LRU)
    private let memory = NSCache<NSURL, UIImage>()

    // MARK: - Disk 설정
    private let maxDiskBytes: UInt64 = 100 * 1024 * 1024        // 100 MB
    private lazy var diskURL: URL = {
        let root = FileManager.default.urls(for: .cachesDirectory,
                                            in: .userDomainMask)[0]
        let dir  = root.appendingPathComponent("com.beme.imagecache",
                                               isDirectory: true)
        try? FileManager.default.createDirectory(at: dir,
                                                 withIntermediateDirectories: true)
        return dir
    }()
    private let ioQueue = DispatchQueue(label: "com.beme.imagecache.disk")

    // MARK: - Public API
    func image(for url: URL) -> UIImage? {
        // 1) 메모리
        if let mem = memory.object(forKey: url as NSURL) { return mem }

        // 2) 디스크
        let path = diskURL.appendingPathComponent(hashedName(for: url))
        guard let data = try? Data(contentsOf: path),
              let img  = UIImage(data: data)
        else { return nil }

        memory.setObject(img, forKey: url as NSURL)
        return img
    }

    func store(_ image: UIImage, for url: URL) {
        memory.setObject(image, forKey: url as NSURL)

        ioQueue.async { [self] in
            let path = diskURL.appendingPathComponent(hashedName(for: url))
            guard let data = image.jpegData(compressionQuality: 0.85) else { return }
            try? data.write(to: path, options: .atomic)
            cleanDiskIfNeeded()
        }
    }

    // MARK: - Helpers
    private func hashedName(for url: URL) -> String {
        let bytes = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hash  = bytes.map { String(format: "%02x", $0) }.joined()
        let ext   = url.pathExtension.isEmpty ? "dat" : url.pathExtension
        return "\(hash).\(ext)"
    }

    private func cleanDiskIfNeeded() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
                at: diskURL,
                includingPropertiesForKeys: [.contentModificationDateKey,
                                             .totalFileAllocatedSizeKey],
                options: .skipsHiddenFiles)
        else { return }

        var total: UInt64 = 0
        var info: [(url: URL, size: UInt64, date: Date)] = []

        for f in files {
            let rv = try? f.resourceValues(forKeys: [.contentModificationDateKey,
                                                     .totalFileAllocatedSizeKey])
            let size = UInt64(rv?.totalFileAllocatedSize ?? 0)
            let date = rv?.contentModificationDate ?? .distantPast
            total += size
            info.append((f, size, date))
        }

        guard total > maxDiskBytes else { return }

        var bytesToRemove = total - maxDiskBytes
        for f in info.sorted(by: { $0.date < $1.date }) where bytesToRemove > 0 {
            try? fm.removeItem(at: f.url)
            bytesToRemove -= f.size
        }
    }
}
