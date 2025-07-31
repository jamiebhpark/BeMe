# 📱 BeMe Challenge

> “하루 1 분, 진짜 일상과 챌린지를 공유하는 Anti‑SNS”
> 
> 
> 광고·알고리즘 피드 없이 **1일 1챌린지**만으로 연결되는 iOS 커뮤니티 앱
> 

Github Link : https://github.com/jamiebhpark/BeMe

Apple Appstore Link : https://apps.apple.com/kr/app/beme-challenge/id6748050854

Intoduction Page : https://quilt-cover-7b9.notion.site/beme-introduce

---

## ✨ 프로젝트 한눈에

|  |  |
| --- | --- |
| **기간 / 인원** | 2025.05 – 개발 중 / 개인 풀‑스택 / 상용 출시 7월 25일 |
| **역할** | iOS 개발 · Firebase 백엔드 · CI/CD, (풀스택) |

---

## 🎯 핵심 기능

1. **60 초 즉석 카메라** – 제한 시간 내 촬영·업로드, 타임아웃 시 자동 롤백
2. **Warm‑Streak®** – 연속 참여 + Grace Day 카드로 가벼운 동기 부여
3. **오프라인 업로드 큐** – BGTaskScheduler 재시도 & 완료 Toast
4. Google Vision AI를 통한 NSFW 이미지 컨텐츠 업로드 방지
5. **신고 10회 자동 삭제** – Cloud Function + Storage 연동
6. **Push & Topic** – 새 챌린지 실시간 알림(`new-challenge`)
7. **챌린지 마감 +7일 모든 정보 삭제** - 운영 비용 및 개인정보 보호 리스크 상쇄
8. 뱃지 부여 - 필수 챌린지(연속 뱃지), 오픈 챌린지(참여 뱃지)

---

## 🏛️ 아키텍처 요약

```
📱 Client (iOS)
│
├─ 🔐 Firebase Authentication (사용자 인증)
│
├─ 🗃️ Firestore Database
│   ├─ users (사용자 데이터 및 참여 기록 관리)
│   ├─ challenges (챌린지 정보 관리)
│   └─ challengePosts (챌린지 참여 게시물 관리)
│
├─ 🖼️ Cloud Storage (이미지 저장 및 관리)
│
├─ ⚙️ Cloud Functions (서버 로직 관리)
│   ├─ 데이터 트랜잭션 처리 (참여 기록, 포스트 등록 등)
│   ├─ 신고 관리 및 자동 삭제 처리
│   └─ 스케줄러 (자동 정리 작업 등)
│
└─ 🤖 Google Vision API (이미지 NSFW 필터링)
```

## 📂 **Firestore 데이터 구조(일부)**

| 컬렉션 (Collection) | 문서 (Document) | 필드 (Field) | 하위 컬렉션 (Subcollection) |
| --- | --- | --- | --- |
| `users` | `{uid}` | `streakCount`, `graceLeft`, `lastDate` | ✅ **`participations`** (`autoId`):`challengeId`, `completed`, `createdAt` |
| `challenges` | `{challengeId}` | `title`, `description`, `endDate`, `participantsCount`, ... | — |
| `challengePosts` | `{postId}` | `challengeId`, `userId`, `imageUrl`, `caption` | ✅ **`comments`** (`commentId`):`userId`, `text`, `createdAt`, `reactions`, `reported`✅ **`reports`** (`uid`) |
| `nicknames` | `{lowercaseNickname}` | `uid`, `createdAt` | — |
| `challengeIdeas` | `{id}` | `isArchived` (boolean) | — |

---

**✅ 모든 데이터 쓰기 작업은 Firebase Cloud Functions 내 트랜잭션을 통해 처리되어, 클라이언트 변조 및 봇을 차단하고 Firestore Rules의 복잡성을 단순화했습니다.**

---

## 🔒 보안·품질 포인트

1. **모든 Callable API 인증 필수** (`uid` 없다면 즉시 401 / Unauthenticated).
2. **입력값 validation** (길이 제한·금칙 문자·중복 ID 등) + 트랜잭션으로 **경합 상태 방지**.
3. **Retry-safe**: Soft-delete(`reported`) 후 실제 삭제를 분리해 idempotent.
4. **Vision SafeSearch** 두 단계(Firestore Trigger & Storage Trigger)로 **우회 업로드 차단**.

---

## 🛠️ 기술 스택

| Layer | Tech |
| --- | --- |
| **iOS** | Swift 5.9 · SwiftUI · Combine · AVFoundation |
| **BaaS** | Firebase Auth · Firestore · Cloud Functions v2 · Cloud Storage · Cloud Messaging ·Google Vision AI |
| **DevOps** | `firebase deploy`(CD) |
| **품질** | ESLint/Prettier · Crashlytics · TestFlight |

---

## ✅ 성과 & 인사이트

- **예비 사용자 테스트(5인)**에서 “60 초 제약이 순간의 진정성을 끌어낸다”는 긍정적 의견 다수
- **오프라인 업로드** 로직 - 비행기 모드, 와이파이 및 셀룰러 Off상태 테스트로 지연 업로드 성공
- **구글 Vison AI 도입**을 통한 NSFW 이미지 검수 시스템 구축 및 업로드 차단
- **신고 및 차단 기능** 도입을 통한 불건전 유저 리스크 축소
- **7일 자동 파기** 정책으로 개인정보·운영 비용 리스크 최소화
- 실제 디바이스 기기 및 테스터 (5인), 시뮬레이터, 상용에 가까운 환경에서 반복 테스트 수행

---

## 🙋🏻‍♂️ 담당 영역

- **iOS 전반** – UI/UX, 카메라, 네트워크 & 캐싱, 이미지 압축 등 전영역 설계 구현
- **백엔드 로직 전반** – 트랜잭션 함수·Scheduler·SafeSearch ·Push 등 전영역 설계·구현
- **DevOps** – 실제 디바이스 기반 통합 테스트, Firebase CLI, Firebase Console

---

## ⚙️ 기술적 도전 및 해결 과정

### 🔹 오프라인 업로드 실패 문제 해결

- **문제 상황**
    
    사용자가 비행기 모드나 오프라인 상태일 때 이미지 업로드가 실패하는 문제 발견.
    
- **해결 방법**
    - Swift의 **`BGTaskScheduler`*를 사용하여 업로드 재시도 큐를 구성했습니다.
    - 네트워크가 복구된 즉시 자동으로 업로드를 재시도하도록 구현하여 문제 해결.
    - 실제 디바이스에서 WiFi 및 셀룰러를 차단한 상태로 반복 테스트 수행, **100% 업로드 성공률** 달성.

### 🔹 NSFW 필터링 우회 시도 차단

- **문제 상황**
    
    일부 NSFW 이미지가 필터링을 통과하지 못하는 상황 발생.
    
- **해결 방법**
    - Firebase **Cloud Storage Trigger**와 **Firestore Trigger**를 모두 활용하여 이미지 업로드 후 2단계로 NSFW 콘텐츠 필터링을 실시했습니다.
    - Google Vision API의 SafeSearch를 통해 **이중 검증 메커니즘**을 구축, NSFW 콘텐츠의 차단 성공률을 높였습니다.

---

## 🛣️ 다음 로드맵

1. 초기 사용자 확보를 위한 주제 아이디어 탐색
2. Admin Page(Next.js) 구현
3. 프로필 뷰 강화

---

> 한 줄 회고
> 
> 
> “**60 초 제약**과 작은 보상이 만나 꾸밈없는 ‘한 장’을 만드는 Anti-SNS.”
> 

## 💡 스크린샷 및 자료

- 1분 앱 Test Video (NSFW 필터링 포함)
    
    [Safety_Features_Demo.mov](attachment:68b432bc-f2c7-4d28-85c3-f149b44b15a4:Safety_Features_Demo.mov)
    
- 1차 심사 Reject 보완 소명자료

[BeMe Challenge — App Store Re‑Submission Dossier.pdf](attachment:e4d53c6f-83f0-4865-bcc6-e2ae8bcdd834:BeMe_Challenge__App_Store_ReSubmission_Dossier.pdf)
