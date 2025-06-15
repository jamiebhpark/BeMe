// Core/Utils/Loadable.swift
import Foundation

enum Loadable<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(Error)
    
    var value: Value? {
        if case .loaded(let v) = self { return v } ; return nil
    }
}
