//
//  NetworkMonitor.swift
//  BeMeChallenge
//

import Foundation
import Network

/// 앱 시작 시 한 번만 listen → offline → online 전환 시 큐 자동 재시도
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(label: "net.monitor")
    
    private init() {
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                Task { await UploadQueue.shared.retryNow() }
            }
        }
        monitor.start(queue: queue)
    }
}
