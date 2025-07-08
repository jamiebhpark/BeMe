/* eslint-disable max-len */
// functions/src/safeSearchScan.ts

import {
  onObjectFinalized,
  StorageObjectData,
} from "firebase-functions/v2/storage";
import {CloudEvent} from "firebase-functions/v2";
import vision from "@google-cloud/vision";
import * as admin from "firebase-admin";

const visionClient = new vision.ImageAnnotatorClient();

export const safeSearchScan = onObjectFinalized(
  {region: "asia-northeast3"},
  async (event: CloudEvent<StorageObjectData>): Promise<void> => {
    console.log("[SafeSearch] 🔔 Triggered for", event.data.name);

    const filePath = event.data.name ?? "";
    const bucket = event.data.bucket ?? "";
    if (
      !(filePath.startsWith("challenge/") || filePath.startsWith("user_uploads/")) ||
      !event.data.contentType?.startsWith("image/")
    ) return;

    const postId = filePath.split("/").pop()?.split(".")[0];
    if (!postId) return;
    const postRef = admin.firestore().doc(`challengePosts/${postId}`);
    const snap = await postRef.get();
    if (!snap.exists) {
      console.log(`[SafeSearch] SKIP ${filePath} (no post document yet)`);
      return;
    }

    const [res] = await visionClient.safeSearchDetection(`gs://${bucket}/${filePath}`);
    const s = res.safeSearchAnnotation;
    console.log("[SafeSearch RAW]", JSON.stringify(s));
    if (!s) return;

    const risky = [s.adult, s.violence, s.racy, s.medical]
      .some((lvl) => lvl === "LIKELY" || lvl === "VERY_LIKELY");

    if (risky) {
      await admin.storage().bucket(bucket).file(filePath).delete();
      await postRef.update({rejected: true});
      console.log(`[SafeSearch] BLOCKED ${filePath}`);
    } else {
      await postRef.update({rejected: false});
      console.log(`[SafeSearch] PASSED  ${filePath}`);
    }
  }
);
