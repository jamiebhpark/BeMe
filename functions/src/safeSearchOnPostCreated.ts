// functions/src/safeSearchOnPostCreated.ts

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import vision from "@google-cloud/vision";
import * as admin from "firebase-admin";

const visionClient = new vision.ImageAnnotatorClient();

// Firestore에 challengePosts/{postId} 문서가 생성되면 실행
export const safeSearchOnPostCreated = onDocumentCreated(
  {region: "asia-northeast3", document: "challengePosts/{postId}"},
  async (event) => {
    const postId = event.params.postId;
    const data = event.data?.data();
    if (!data) return;

    // 이미지 URL에서 bucket & filePath 파싱
    const url = data.imageUrl as string;
    const encoded = url.split("/o/")[1]?.split("?")[0];
    if (!encoded) return;
    const filePath = decodeURIComponent(encoded);
    const bucket = process.env.STORAGE_BUCKET || admin.storage().bucket().name;

    // Vision SafeSearch
    const [res] = await visionClient.safeSearchDetection(`gs://${bucket}/${filePath}`);
    const s = res.safeSearchAnnotation;
    if (!s) return;

    // LIKELY 이상인 카테고리가 하나라도 있으면 위험
    const risky = [s.adult, s.violence, s.racy, s.medical]
      .some((lvl) => lvl === "LIKELY" || lvl === "VERY_LIKELY");

    const postRef = admin.firestore().doc(`challengePosts/${postId}`);

    if (risky) {
      // 위험하면 파일 삭제, rejected=true
      await admin.storage().bucket(bucket).file(filePath).delete();
      await postRef.update({rejected: true});

      // 차단 알림 (FCM v1 방식)
      const uid = data.userId as string | undefined;
      if (uid) {
        await admin.messaging().send({
          topic: `user-${uid}`,
          notification: {
            title: "⛔️ 업로드 차단",
            body: "부적절한 이미지가 차단되었습니다",
          },
        });
      }
    } else {
      // 정상 통과
      await postRef.update({rejected: false});
    }
  }
);
