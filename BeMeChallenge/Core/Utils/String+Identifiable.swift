//  String+Identifiable.swift
import Foundation

extension String: @retroactive Identifiable {   // 👈 위치 수정
    public var id: String { self }
}
