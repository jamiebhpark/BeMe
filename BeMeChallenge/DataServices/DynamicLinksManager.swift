//DynamicLinksManager.swift
import FirebaseDynamicLinks
import UIKit

class DynamicLinksManager {
    static let shared = DynamicLinksManager()

    private let domainURIPrefix = "https://bemechallenge.page.link"

    /// 챌린지 단위 공유 (기존)
    func generateDynamicLink(forChallenge challengeId: String,
                             completion: @escaping (URL?) -> Void) {
        guard let link = URL(string: "https://bemechallenge.com/challenge/\(challengeId)") else {
            completion(nil); return
        }
        makeLink(from: link, completion: completion)
    }

    /// **포스트 단위** 공유용 딥링크 생성
    func generateDynamicLink(forPost post: Post,
                             completion: @escaping (URL?) -> Void) {
        // 예: /challenge/{challengeId}/post/{postId}
        guard let link = URL(string:
            "https://bemechallenge.com/challenge/\(post.challengeId)/post/\(post.id)"
        ) else {
            completion(nil); return
        }
        makeLink(from: link, completion: completion)
    }

    /// 공통 빌더
    private func makeLink(from link: URL,
                          completion: @escaping (URL?) -> Void) {
        guard let builder = DynamicLinkComponents(
            link: link,
            domainURIPrefix: domainURIPrefix
        ) else {
            completion(nil); return
        }

        // iOS 파라미터
        let ios = DynamicLinkIOSParameters(bundleID: Bundle.main.bundleIdentifier!)
        ios.appStoreID = "123456789" // 실제 ID
        builder.iOSParameters = ios

        // 소셜 미리보기
        let social = DynamicLinkSocialMetaTagParameters()
        social.title = "BeMe Challenge"
        social.descriptionText = "진짜 일상을 나누는 챌린지, 지금 확인해보세요!"
        // 대표 이미지가 있으면 여기에 URL
        // social.imageURL = URL(string: "https://bemechallenge.com/assets/share.png")
        builder.socialMetaTagParameters = social

        // 단축 링크 생성
        builder.shorten { url, _, error in
            if let error = error {
                print("🔗 Dynamic Link error:", error)
            }
            completion(url)
        }
    }

    /// 앱 실행 시 딥링크 처리 (기존)
    func handleDynamicLink(_ dynamicLink: DynamicLink?) -> String? {
        guard let url = dynamicLink?.url else { return nil }
        let comps = url.pathComponents
        if comps.count >= 5,
           comps[1] == "challenge",
           comps[3] == "post" {
            return comps[4] // postId
        }
        // 혹은 challenge-only
        if comps.count >= 3, comps[1] == "challenge" {
            return comps[2]
        }
        return nil
    }
}
