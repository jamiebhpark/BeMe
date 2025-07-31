```markdown
# 📱 BeMe Challenge

> 하루 1분, 꾸밈없이 진짜 일상을 공유하는 **Anti-SNS iOS 커뮤니티 앱**

## 🎯 프로젝트 소개

**BeMe Challenge**는 기존 SNS의 과도한 꾸밈과 광고, 추천 알고리즘에서 벗어나, 사용자의 진정성 있는 순간을 담기 위한 iOS 앱입니다.  
매일 하나의 챌린지를 제한된 시간(60초) 내 즉석 카메라로 촬영하여 공유하고 소통하는 방식으로, 진짜 일상을 공유하는 문화를 지향합니다.

🔗 [App Store에서 보기](https://apps.apple.com/kr/app/beme-challenge/id6748050854)

## ✨ 주요 기능

- **60초 즉석 카메라** – 제한 시간 내 즉시 촬영하여 업로드 (롤백 시스템 적용)
- **Warm-Streak® 시스템** – 지속적인 참여를 독려하는 연속 챌린지 및 Grace Day 카드 제공
- **Google Vision API 기반 NSFW 필터링** – 업로드 단계에서 즉시 부적절한 콘텐츠 자동 필터링
- **오프라인 업로드 큐** – BGTaskScheduler를 이용해 오프라인 상태에서도 안정적인 업로드 지원
- **사용자 신고 및 콘텐츠 자동 삭제** – 10회 신고 누적 시 콘텐츠 자동 삭제 (Firebase Functions 연동)
- **챌린지 정보 자동 삭제** – 챌린지 종료 7일 후 개인정보 보호를 위한 데이터 자동 삭제

## 🧩 프로젝트 구조

```

BeMe
├── 📁 Application
│     ├── AppDelegate.swift
│     ├── MainView\.swift
│     └── SceneDelegate.swift
├── 📁 Presentation
│     ├── Views (SwiftUI)
│     ├── ViewModels (Combine)
│     └── Components (재사용 UI 컴포넌트)
├── 📁 Domain
│     ├── Models
│     └── UseCases
├── 📁 Data
│     ├── FirebaseServices (Firestore, Storage)
│     └── VisionAPI (Google Vision AI)
├── 📁 Utils
│     ├── Extensions
│     └── Helpers
└── 📁 Resources
├── Assets.xcassets
└── LaunchScreen.storyboard

```

## 🛠️ 기술 스택

| 분야 | 기술 |
|------|------|
| 프론트엔드 | Swift 5.9, SwiftUI, Combine, AVFoundation |
| 백엔드 (BaaS) | Firebase Auth, Firestore, Cloud Storage, Cloud Functions, Cloud Messaging |
| AI 및 필터링 | Google Vision API (SafeSearch) |
| CI/CD 및 배포 | Firebase CLI, TestFlight |
| 테스트 및 품질관리 | XCTest, Crashlytics |

## 🚨 기술적 도전 및 해결 과정

- **오프라인 업로드 문제 해결**
  - **문제:** 오프라인 상태에서 이미지 업로드 실패 발생
  - **해결:** `BGTaskScheduler`를 활용한 업로드 재시도 큐 구현하여 비행기모드에서도 안정적 업로드 보장

- **NSFW 필터링 우회 방지**
  - **문제:** NSFW 필터링 우회 시도 발생
  - **해결:** Cloud Storage Trigger 및 Firestore Trigger의 이중 검증 로직 구축으로 완벽한 차단 구현

## 🚀 성과 및 사용자 반응

- 초기 사용자 테스트에서 **"진정성 있는 콘텐츠 공유가 가능하다"**는 긍정적인 피드백 확보
- 앱스토어 정식 출시 및 운영 경험을 통해 사용자 중심의 지속적인 이터레이션 진행 중

## 🛣️ 앞으로의 계획

- 초기 사용자 확보 및 챌린지 주제 다양화
- Next.js 기반 Admin 관리 페이지 구축
- 프로필 페이지 및 사용자 참여도 개선

## 📝 라이선스

MIT License © [박종훈](https://github.com/jamiebhpark)
```

