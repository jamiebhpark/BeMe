// Core/Utils/LoadableProgress.swift
import Foundation

/// 0 … 1 사이의 진행률을 갖는 Loadable
enum LoadableProgress {
    case idle
    case running(Double)    // 0.0 ~ 1.0
    case succeeded
    case failed(Error)
    
    var percent: Double {
        if case .running(let p) = self { return p } ; return 0
    }
}
