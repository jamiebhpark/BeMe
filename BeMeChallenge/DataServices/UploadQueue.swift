//
//  UploadQueue.swift
//  BeMeChallenge
//

import Foundation
import BackgroundTasks
import FirebaseAuth
import FirebaseStorage
import FirebaseFunctions
import UIKit                  // ✅ Notification.Name 정의용

// MARK: - 완료 브로드캐스트용 Notification
extension Notification.Name {
    /// 모든 PendingUpload 처리가 끝났을 때(성공·포기 포함) 발송
    static let uploadQueueDidFlush = Notification.Name("uploadQueueDidFlush")
}

/// 실패한 업로드 정보를 담는 구조체
struct PendingUpload: Codable, Identifiable {
    let id: String
    let uid: String
    let cid: String
    let imgPath: String      // 앱 sandbox 내 이미지 파일 경로
    let caption: String?
    var retry: Int
    
    init(uid: String, cid: String, imgPath: String, caption: String?) {
        self.id = UUID().uuidString
        self.uid = uid
        self.cid = cid
        self.imgPath = imgPath
        self.caption = caption
        self.retry = 0
    }
}

/// 싱글톤 큐 매니저
@MainActor
final class UploadQueue: ObservableObject {
    static let shared = UploadQueue()
    
    @Published private(set) var items: [PendingUpload] = []
    private let storeKey = "PendingUploads"
    private let maxRetry = 5
    
    private init() {
        load()
        registerBGTask()
    }
    
    // MARK: - Public API
    /// 업로드 실패 항목을 큐에 저장
    func enqueue(uid: String, cid: String, image: UIImage, caption: String?) {
        guard let data = image.pngData() else { return }
        let tmpURL = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(UUID().uuidString).png")
        try? data.write(to: tmpURL)
        
        let item = PendingUpload(uid: uid, cid: cid, imgPath: tmpURL.path, caption: caption)
        items.append(item);  save()
        scheduleBGTask()
    }
    
    /// 디버그용 수동 재시도
    func retryNow() {
        Task.detached { await self.processQueue() }
    }
    
    // MARK: - BG Task
    private func registerBGTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BGIdentifiers.uploadRetry,
            using: nil
        ) { [weak self] task in
            Task.detached {
                await self?.processQueue()             // ① 백그라운드에서 재시도
                task.setTaskCompleted(success: true)
                await MainActor.run { self?.scheduleBGTask() } // ② 남은 항목 있으면 재예약
            }
        }
    }
    
    private func scheduleBGTask() {
        guard !items.isEmpty else { return }
        let req = BGAppRefreshTaskRequest(identifier: BGIdentifiers.uploadRetry)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15분 후
        try? BGTaskScheduler.shared.submit(req)
    }
    
    // MARK: - Core Logic
    private func processQueue() async {
        guard !items.isEmpty else { return }
        print("🔄 UploadQueue retry started, count:", items.count)
        
        var succeeded: [String] = []
        for var item in items {
            guard let img = UIImage(contentsOfFile: item.imgPath) else { continue }
            do {
                try await upload(item: item, image: img)
                succeeded.append(item.id)
                try? FileManager.default.removeItem(atPath: item.imgPath)
            } catch {
                print("upload retry err:", error.localizedDescription)
                item.retry += 1
                if item.retry >= maxRetry { succeeded.append(item.id) } // give-up
            }
        }
        
        items.removeAll { succeeded.contains($0.id) }
        save()
        
        // 모든 대기 항목이 사라졌다면 → Notification 발송
        await MainActor.run {
            if items.isEmpty {
                NotificationCenter.default.post(name: .uploadQueueDidFlush, object: nil)
            }
        }
    }
    
    // MARK: - 실제 업로드
    private func upload(item: PendingUpload, image: UIImage) async throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw NSError() }
        let ref = Storage.storage()
            .reference()
            .child("user_uploads/\(item.uid)/\(item.cid)/\(UUID().uuidString).jpg")
        _ = try await ref.putDataAsync(data)            // ① Storage
        let url = try await ref.downloadURL()
        
        // ② Cloud Function createPost 호출
        let payload: [String: Any?] = [
            "challengeId": item.cid,
            "imageUrl":    url.absoluteString,
            "caption":     item.caption ?? NSNull()
        ]
        try await Functions.functions(region: "asia-northeast3")
            .httpsCallable("createPost")
            .call(payload)
    }
    
    // MARK: - Persistence
    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storeKey)
    }
    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storeKey),
            let list = try? JSONDecoder().decode([PendingUpload].self, from: data)
        else { return }
        items = list
    }
}
