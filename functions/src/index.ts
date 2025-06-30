/* eslint-disable @typescript-eslint/no-empty-function */
/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
/* eslint-disable no-constant-condition */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {DateTime} from "luxon"; // ★ 타임존 안전

admin.initializeApp();

// ───────────────────── 0-A. reserveNickname ─────────────────────
const RESERVED = ["운영자", "admin", "administrator", "관리자"];

export const reserveNickname = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

    const raw = String(data.nickname ?? "").trim();
    if (raw.length === 0 || raw.length > 20) {
      throw new HttpsError("invalid-argument", "닉네임은 1–20자여야 합니다.");
    }
    if (RESERVED.includes(raw)) {
      throw new HttpsError("already-exists", "사용할 수 없는 닉네임입니다.");
    }

    const key = raw.toLowerCase(); // 대/소문자 무시
    const db = admin.firestore();
    const map = db.collection("nicknames").doc(key);
    const user= db.collection("users").doc(uid);

    await db.runTransaction(async (tx) => {
      if ((await tx.get(map)).exists) {
        throw new HttpsError("already-exists", "이미 사용 중인 닉네임입니다.");
      }

      tx.set(map, {uid, createdAt: admin.firestore.FieldValue.serverTimestamp()});
      tx.set(user, {nickname: raw}, {merge: true});
    });

    return {success: true, nickname: raw};
  }
);
/* ──────────────────────────────── Utils ─────────────────────────────── */

/**
 * Returns a Firestore `Timestamp` representing **midnight (00:00)** in the Asia/Seoul
 * time‑zone for the given date.
 *
 * @param {DateTime} [date=DateTime.now()] – The reference time. Defaults to `DateTime.now()`.
 * @return {admin.firestore.Timestamp} Midnight of the same calendar day in KST.
 */
function startOfKST(date = DateTime.now()): admin.firestore.Timestamp {
  const kst = date.setZone("Asia/Seoul").startOf("day");
  return admin.firestore.Timestamp.fromMillis(kst.toMillis());
}

/**
 * Lightweight profanity filter based on a single regular expression.
 *
 * @param {string} [text=""] – Text to evaluate.
 * @return {boolean} `true` if the text contains blocked words, otherwise `false`.
 */
function containsBadWords(text = ""): boolean {
  const rx = /(시\s*발|씨\s*발|ㅅ\s*ㅂ|좆|존나|f+u+c*k+|s+h+i+t+|b+i+t+c+h+)/i;
  return rx.test(text);
}

export const participateChallenge = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    /* 0) 인증 · 파라미터 */
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인 필요");

    const {challengeId, type} = data as { challengeId?: string; type?: string };
    if (!challengeId || !type) {
      throw new HttpsError("invalid-argument", "challengeId/type 필수");
    }

    const db = admin.firestore();

    /* 1) 중복 참여(필수 챌린지) 검사 */
    if (type === "필수") {
      const dup = await db.collection("users").doc(uid)
        .collection("participations")
        .where("challengeId", "==", challengeId)
        .where("createdAt", ">=", startOfKST())
        .limit(1).get();
      if (!dup.empty) throw new HttpsError("already-exists", "오늘 이미 참여");
    }

    /* 2) 챌린지 상태 확인 */
    const chRef = db.collection("challenges").doc(challengeId);
    const chSnap = await chRef.get();
    if (!chSnap.exists) throw new HttpsError("not-found", "챌린지 없음");
    if (chSnap.get("endDate")?.toDate() <= new Date()) {
      throw new HttpsError("failed-precondition", "종료된 챌린지");
    }

    /* 3) 배치로 참여 문서 + 카운트 증가 */
    const partRef = db.collection("users").doc(uid)
      .collection("participations").doc();

    const batch = db.batch();
    batch.set(partRef, {
      userId: uid,
      challengeId,
      type,
      completed: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.update(chRef, {
      participantsCount: admin.firestore.FieldValue.increment(1),
    });
    await batch.commit();

    return {success: true, participationId: partRef.id};
  }
);

/* ─────────────────────────── 2. createPost ─────────────────────────── */
export const createPost = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

    const {challengeId, imageUrl, caption, participationId} = data as {
      challengeId?: string; imageUrl?: string; caption?: string; participationId?: string;
    };
    if (!challengeId || !imageUrl) {
      throw new HttpsError("invalid-argument", "필수 값 누락");
    }
    if (caption && caption.length > 80) {
      throw new HttpsError("invalid-argument", "캡션 80자 이하");
    }
    if (caption && containsBadWords(caption)) {
      throw new HttpsError("failed-precondition", "부적절한 표현");
    }

    const db = admin.firestore();
    await db.collection("challengePosts").add({
      challengeId,
      userId: uid,
      imageUrl,
      caption: caption ?? null,
      participationId: participationId ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      reactions: {}, reported: false,
    });

    if (participationId) {
      await db.collection("users").doc(uid)
        .collection("participations").doc(participationId)
        .update({completed: true});
    }

    return {success: true};
  },
);

/* ───────────────────────── 3. cancelParticipation ──────────────────── */
export const cancelParticipation = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인 필요");

    const {challengeId, participationId} = data as {
      challengeId?: string; participationId?: string;
    };
    if (!challengeId || !participationId) {
      throw new HttpsError("invalid-argument", "잘못된 요청");
    }

    const db = admin.firestore();
    const chRef = db.collection("challenges").doc(challengeId);
    const partRef = db.collection("users").doc(uid)
      .collection("participations").doc(participationId);

    await db.runTransaction(async (tx) => {
      const part = await tx.get(partRef);
      if (!part.exists || part.get("completed")) return;

      /* participantsCount 음수 방지 */
      const ch = await tx.get(chRef);
      const cur = (ch.get("participantsCount") as number) || 0;
      if (cur > 0) tx.update(chRef, {participantsCount: cur - 1});

      tx.delete(partRef);
    });

    return {success: true};
  },
);

/* ──────────────── 4. purgeUnfinishedParticipations (schedule) ───────── */
/* 5분 → 15분, CollectionGroup + Batch */
export const purgeUnfinishedParticipations = onSchedule(
  {region: "asia-northeast3", schedule: "every 15 minutes", timeZone: "Asia/Seoul"},
  async () => {
    const db = admin.firestore();
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 15 * 60_000);

    const snap = await db.collectionGroup("participations")
      .where("completed", "==", false)
      .where("createdAt", "<=", cutoff)
      .limit(5000).get();
    if (snap.empty) return;

    const bw = db.bulkWriter();
    for (const d of snap.docs) {
      const data = d.data();
      const cid = data.challengeId as string | undefined;

      if (cid) {
        const chRef = db.collection("challenges").doc(cid);
        bw.update(chRef, {
          participantsCount: admin.firestore.FieldValue.increment(-1),
        });
      }
      bw.delete(d.ref);
    }
    await bw.close();
    console.log(`[purgeUnfinished] removed=${snap.size}`);
  },
);

/* ───────────────────── 5. Warm‑Streak Updater ─────────────────────── */
export const onPostCreatedUpdateStreak = onDocumentCreated(
  {region: "asia-northeast3", document: "challengePosts/{postId}"},
  async (event) => {
    const snap = event.data; if (!snap) return;

    const uid = snap.get("userId") as string | undefined;
    if (!uid) return;

    const todayRaw = DateTime.now().setZone("Asia/Seoul").toISODate();
    if (!todayRaw) {
      console.error("[Streak] toISODate() returned null");
      return;
    }
    const todayStr = todayRaw;

    const db = admin.firestore();
    const ref = db.collection("users").doc(uid);

    await db.runTransaction(async (tx) => {
      const user = await tx.get(ref);

      const MAX_GRACE = 2;

      const curStreak = (user.get("streakCount") as number) || 0;
      const lastDate = (user.get("lastDate") as string) || "";
      const graceLeft = (user.get("graceLeft") as number) || MAX_GRACE;

      const diff = lastDate ?
        DateTime.fromISO(todayStr).diff(DateTime.fromISO(lastDate), "days").days :
        0;

      let streak = curStreak;
      let grace = graceLeft;
      let reset = false;

      if (diff === 0) {
        if (curStreak === 0 || lastDate === "") {
          streak = 1; grace = MAX_GRACE;
        } else return;
      } else if (diff === 1) {
        streak += 1; grace = MAX_GRACE;
      } else if (diff <= MAX_GRACE + 1) {
        streak += 1; grace = MAX_GRACE - (diff - 1);
      } else {
        streak = 1; grace = MAX_GRACE; reset = true;
      }

      tx.set(ref, {
        streakCount: streak,
        graceLeft: grace,
        lastDate: todayStr,
        streakUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      if (reset) console.log(`[StreakReset] uid=${uid}`);
    });
  },
);

/* ───────────────────── 6. purgeOldChallenges (schedule) ────────────── */
export const purgeOldChallenges = onSchedule(
  {region: "asia-northeast3", schedule: "every 1 hours", timeZone: "Asia/Seoul"},
  async () => {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();
    const cutoff = DateTime.now().minus({days: 7}).toJSDate();

    const expired = await db.collection("challenges")
      .where("endDate", "<=", cutoff).get();
    const expiredIds = expired.docs.map((d) => d.id);

    const orphanIds = new Set<string>();
    const existsMap = new Map<string, boolean>();

    let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;

    // eslint-disable-next-line no-constant-condition
    while (true) {
      let q = db.collection("challengePosts")
        .orderBy(admin.firestore.FieldPath.documentId()).limit(500);
      if (cursor) q = q.startAfter(cursor);

      const snap = await q.get(); if (snap.empty) break;

      for (const d of snap.docs) {
        cursor = d;
        const cid = d.get("challengeId") as string;
        if (existsMap.has(cid)) {
          if (!existsMap.get(cid)) orphanIds.add(cid);
        } else {
          const exists = (await db.collection("challenges").doc(cid).get()).exists;
          existsMap.set(cid, exists);
          if (!exists) orphanIds.add(cid);
        }
      }
    }

    const targets = new Set([...expiredIds, ...orphanIds]);
    let chDel = 0; let postDel = 0; let fileDel = 0;

    for (const cid of targets) {
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const ps = await db.collection("challengePosts")
          .where("challengeId", "==", cid).limit(500).get();
        if (ps.empty) break;

        const bw = db.bulkWriter();
        for (const p of ps.docs) {
          bw.delete(p.ref); postDel++;
          const url = p.get("imageUrl") as string | undefined;
          if (url?.includes("/o/")) {
            const gs = decodeURIComponent(url.split("/o/")[1]?.split("?")[0] || "");
            try {
              await bucket.file(gs).delete(); fileDel++;
            } catch (err) {
              console.warn(`[purgeOld] file delete failed: ${(err as Error).message}`);
            }
          }
        }
        await bw.close();
      }
      if ((await db.collection("challenges").doc(cid).get()).exists) {
        await db.collection("challenges").doc(cid).delete(); chDel++;
      }
    }
    console.log(`[purgeOld] ch=${chDel} post=${postDel} file=${fileDel}`);
  },
);

/* ───────────────────── 7. reportPost & onReportCreated ─────────────── */
export const reportPost = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    const uid = auth?.uid; if (!uid) throw new HttpsError("unauthenticated", "로그인 필요");

    const {postId} = data as { postId?: string };
    if (!postId) throw new HttpsError("invalid-argument", "postId 필수");

    const db = admin.firestore();
    const post = db.collection("challengePosts").doc(postId);
    const rep = post.collection("reports").doc(uid);

    await db.runTransaction(async (tx) => {
      const pSnap = await tx.get(post);
      if (!pSnap.exists) throw new HttpsError("not-found", "이미 삭제된 글");
      if ((await tx.get(rep)).exists) throw new HttpsError("already-exists", "중복 신고");
      tx.set(rep, {createdAt: admin.firestore.FieldValue.serverTimestamp()});
    });
    return {success: true};
  },
);

export const onReportCreated = onDocumentCreated(
  {region: "asia-northeast3", document: "challengePosts/{postId}/reports/{uid}"},
  async (event) => {
    const postId = event.params.postId;
    const db = admin.firestore();
    const post = db.collection("challengePosts").doc(postId);

    await db.runTransaction(async (tx) => {
      const reps = await post.collection("reports").count().get();
      if (reps.data().count < 10) return;

      tx.update(post, {reported: true}); // 중복 delete 방지
    });

    /* reported 플래그 확인 후 실제 삭제 */
    const pSnap = await post.get();
    if (pSnap.exists && pSnap.get("reported") === true) {
      await post.delete();

      const url = pSnap.get("imageUrl") as string | null;
      if (url && url.includes("/o/")) {
        const gs = decodeURIComponent(url.split("/o/")[1]?.split("?")[0] || "");
        try {
          await admin.storage().bucket().file(gs).delete();
        } catch (err) {
          console.warn(`[onReport] file delete failed: ${(err as Error).message}`);
        }
      }
    }
  },
);

/* ─────────────────── 8. sendNewChallengePush ──────────────────────── */
export const sendNewChallengePush = onDocumentCreated(
  {region: "asia-northeast3", document: "challenges/{cid}"},
  async (event) => {
    const data = event.data?.data(); if (!data) return;

    await admin.messaging().send({
      topic: "new-challenge",
      notification: {
        title: String(data.title ?? "새 챌린지!"),
        body: String(data.description ?? ""),
      },
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
      data: {type: "challenge", challengeId: event.params.cid},
    });

    console.log(`[sendNewChallengePush] ${event.params.cid} sent`);
  },
);
/* ───────── 0-B. onChallengeIdeaArchived ────────── */
/** isArchived 가 true 로 바뀌면 문서를 완전 삭제 */
export const onChallengeIdeaArchived = onDocumentUpdated(
  {
    region: "asia-northeast3",
    document: "challengeIdeas/{id}",
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;

    // ① isArchived 값이 false → true 로 변경된 경우만
    if (before?.isArchived === false && after.isArchived === true) {
      const db = admin.firestore();
      await db.collection("challengeIdeas")
        .doc(event.params.id)
        .delete();
      console.log(`[IdeaDeleted] ${event.params.id}`);
    }
  }
);
