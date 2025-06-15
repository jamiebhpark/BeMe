//  ImageCache.swift
//  BeMeChallenge
import UIKit

/// 메모리(LRU) + 디스크 캐시를 동시에 제공하는 싱글턴
final class ImageCache {
    
    // MARK: - Singleton
    static let shared = ImageCache()
    private init() { }
    
    // MARK: - Properties
    /// 메모리 캐시 (NSCache → 자동 LRU)
    private let memory = NSCache<NSURL, UIImage>()
    /// 디스크 캐시 경로   caches/com.beme.images/*
    private lazy var diskURL: URL = {
        let root = FileManager.default.urls(for: .cachesDirectory,
                                            in: .userDomainMask)[0]
        let dir  = root.appendingPathComponent("com.beme.imagecache",
                                               isDirectory: true)
        try? FileManager.default.createDirectory(at: dir,
                                                 withIntermediateDirectories: true)
        return dir
    }()
    
    // 디스크 캐시 용량 제한(예: 50 MB)
    private let maxDiskBytes: UInt64 = 50 * 1024 * 1024
    
    // MARK: - Public API
    /// 캐시에서 즉시 반환(없으면 nil)
    func image(for url: URL) -> UIImage? {
        if let mem = memory.object(forKey: url as NSURL) { return mem }
        let path = diskURL.appendingPathComponent(url.lastPathComponent)
        if let data = try? Data(contentsOf: path),
           let img  = UIImage(data: data) {
            memory.setObject(img, forKey: url as NSURL)
            return img
        }
        return nil
    }
    
    /// 이미지를 메모리·디스크에 저장
    func store(_ image: UIImage, for url: URL) {
        memory.setObject(image, forKey: url as NSURL)
        let path = diskURL.appendingPathComponent(url.lastPathComponent)
        // PNG보다 JPEG(85%)가 파일 크기가 작아 대부분 적합
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: path, options: .atomic)
        cleanDiskIfNeeded()
    }
    
    /// 디스크 캐시 정리(가장 오래된 파일부터 삭제)
    private func cleanDiskIfNeeded() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: diskURL,
                                                      includingPropertiesForKeys: [.contentModificationDateKey,
                                                                                    .totalFileAllocatedSizeKey],
                                                      options: .skipsHiddenFiles)
        else { return }
        
        var total: UInt64 = 0
        var fileInfos: [(url: URL, size: UInt64, date: Date)] = []
        for fileURL in files {
            let res = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey,
                                                            .contentModificationDateKey])
            let size = UInt64(res?.totalFileAllocatedSize ?? 0)
            let date = res?.contentModificationDate ?? .distantPast
            total += size
            fileInfos.append((fileURL, size, date))
        }
        
        guard total > maxDiskBytes else { return }
        // 오래된 파일부터 삭제
        let sorted = fileInfos.sorted { $0.date < $1.date }
        var bytesToRemove = total - maxDiskBytes
        for info in sorted where bytesToRemove > 0 {
            try? fm.removeItem(at: info.url)
            bytesToRemove -= info.size
        }
    }
}
