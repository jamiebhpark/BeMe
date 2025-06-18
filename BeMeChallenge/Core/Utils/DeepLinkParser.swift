// DeepLinkParser.swift  (새 파일)
import Foundation

enum DeepLinkParser {
    /// URL ➜ challengeId 추출  (예: https://beme.app/challenge/abc123 → \"abc123\")
    static func challengeId(from url: URL) -> String? {
        guard url.host?.contains("beme.app") == true else { return nil }
        let comps = url.pathComponents                       // [\"/\", \"challenge\", \"abc123\"]
        if comps.count >= 3, comps[1] == "challenge" {
            return comps[2]
        }
        return nil
    }
}
