// ExplicitNull.swift
@propertyWrapper
public struct ExplicitNull<Value: Codable>: Codable {   // ← public 추가
    public var wrappedValue: Value?

    // MARK: - Init
    public init(wrappedValue: Value?) {
        self.wrappedValue = wrappedValue
    }

    // MARK: - Codable
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self.wrappedValue = try? c.decode(Value?.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if let value = wrappedValue {
            try c.encode(value)
        }
        // nil 은 그냥 필드 생략; null 을 기록하려면 else { try c.encodeNil() }
    }
}
