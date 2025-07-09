//  BlockedUsersView.swift

import SwiftUI
import FirebaseFirestore

struct BlockedUsersView: View {
    @StateObject private var blockManager = BlockManager.shared
    @State private var userNames: [String: String] = [:]

    var body: some View {
        List {
            if blockManager.blockedUserIds.isEmpty {
                Text("차단된 사용자가 없습니다.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(blockManager.blockedUserIds), id: \.self) { uid in
                    HStack {
                        Text(userNames[uid] ?? uid)
                        Spacer()
                        Button("해제") {
                            BlockService.shared.unblock(userId: uid) { res in
                                DispatchQueue.main.async {
                                    switch res {
                                    case .success:
                                        // BlockManager가 자동으로 갱신해줍니다
                                        break
                                    case .failure:
                                        // 실패 시 토스트 등으로 안내
                                        // modalC.showToast(ToastItem(message: "해제 실패"))
                                        break
                                    }
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .onAppear {
                        // 닉네임 캐시가 없으면 Firestore에서 불러오기
                        if userNames[uid] == nil {
                            Firestore.firestore()
                                .collection("users")
                                .document(uid)
                                .getDocument { snap, _ in
                                    if let name = snap?.get("nickname") as? String {
                                        userNames[uid] = name
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("차단된 사용자")
        .listStyle(.insetGrouped)
    }
}
