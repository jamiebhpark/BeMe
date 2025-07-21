/* eslint-disable @typescript-eslint/no-empty-function */
/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
/* eslint-disable no-constant-condition */

import {
  onCall,
  HttpsError,
} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {
  onDocumentCreated,
  onDocumentUpdated,
  //  FirestoreEvent,
} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {DateTime} from "luxon";
import {FieldValue} from "firebase-admin/firestore";

admin.initializeApp();

/* ───────────────────── Utils ───────────────────── */
const RESERVED = ["운영자", "admin", "administrator", "관리자"].map((w) =>
  w.toLowerCase()
);
function startOfKST(date = DateTime.now()): admin.firestore.Timestamp {
  const kst = date.setZone("Asia/Seoul").startOf("day");
  return admin.firestore.Timestamp.fromMillis(kst.toMillis());
}
function containsBadWords(text = ""): boolean {
  return /(시\s*발|씨\s*발|ㅅ\s*ㅂ|좆|존나|f+u+c*k+|s+h+i+t+|b+i+t+c+h+)/i.test(
    text
  );
}

/* ────────── 0. 닉네임 예약 ────────── */
export const reserveNickname = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

    const raw = String(data.nickname ?? "").trim();
    if (raw.length === 0 || raw.length > 20) {
      throw new HttpsError("invalid-argument", "닉네임은 1‒20자여야 합니다.");
    }

    const key = raw.toLowerCase();
    if (RESERVED.includes(key)) {
      throw new HttpsError("already-exists", "사용할 수 없는 닉네임입니다.");
    }

    const db = admin.firestore();
    const mapRef = db.collection("nicknames").doc(key);
    const userRef = db.collection("users").doc(uid);

    await db.runTransaction(async (tx) => {
      if ((await tx.get(mapRef)).exists) {
        throw new HttpsError("already-exists", "이미 사용 중인 닉네임입니다.");
      }

      const prev = (await tx.get(userRef)).get("nickname");
      if (prev && prev.toLowerCase() !== key) {
        tx.delete(db.collection("nicknames").doc(prev.toLowerCase()));
      }

      tx.set(mapRef, {
        uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.set(userRef, {nickname: raw}, {merge: true});
    });

    return {success: true, nickname: raw};
  }
);

/* ────────── 1. 챌린지 참여 ────────── */
export const participateChallenge = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인 필요");

    const {challengeId, type} = data as {
      challengeId?: string;
      type?: string;
    };
    if (!challengeId || !type) {
      throw new HttpsError("invalid-argument", "challengeId/type 필수");
    }

    const db = admin.firestore();

    if (type === "필수") {
      const dup = await db
        .collection("users")
        .doc(uid)
        .collection("participations")
        .where("challengeId", "==", challengeId)
        .where("createdAt", ">=", startOfKST())
        .limit(1)
        .get();
      if (!dup.empty) {
        throw new HttpsError("already-exists", "오늘 이미 참여");
      }
    }

    const chRef = db.collection("challenges").doc(challengeId);
    const chSnap = await chRef.get();
    if (!chSnap.exists) throw new HttpsError("not-found", "챌린지 없음");
    if (chSnap.get("endDate")?.toDate() <= new Date()) {
      throw new HttpsError("failed-precondition", "종료된 챌린지");
    }

    const partRef = db
      .collection("users")
      .doc(uid)
      .collection("participations")
      .doc();
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

/* ────────── 2. 게시물 생성 ────────── */
export const createPost = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

    const {
      postId,
      challengeId,
      imageUrl,
      caption,
      participationId,
    } = data as {
      postId?: string;
      challengeId?: string;
      imageUrl?: string;
      caption?: string;
      participationId?: string;
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
    const posts = db.collection("challengePosts");
    const docRef = postId ? posts.doc(postId) : posts.doc();

    if ((await docRef.get()).exists) {
      throw new HttpsError("already-exists", "동일 ID 문서가 이미 존재합니다.");
    }

    await docRef.set({
      challengeId,
      userId: uid,
      imageUrl,
      caption: caption ?? null,
      participationId: participationId ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      reactions: {},
      reported: false,
      commentsCount: 0,
    });

    if (participationId) {
      await db
        .collection("users")
        .doc(uid)
        .collection("participations")
        .doc(participationId)
        .update({completed: true});
    }

    return {success: true, postId: docRef.id};
  }
);

/* ────────── 3. 캡션 수정 ────────── */
export const updateCaption = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

    const {postId, newCaption} = data as {
      postId?: string;
      newCaption?: string;
    };
    if (!postId || newCaption === undefined) {
      throw new HttpsError("invalid-argument", "postId / newCaption 필수");
    }

    const body = String(newCaption).trim();
    if (body.length > 80) {
      throw new HttpsError("invalid-argument", "80자 이내");
    }
    if (containsBadWords(body)) {
      throw new HttpsError("failed-precondition", "부적절한 표현");
    }

    const postRef = admin.firestore().collection("challengePosts").doc(postId);
    const snap = await postRef.get();
    if (!snap.exists || snap.get("userId") !== uid) {
      throw new HttpsError("permission-denied", "권한 없음");
    }

    await postRef.update({caption: body});
    return {success: true};
  }
);

/* ────────── 4. 참여 취소 ────────── */
export const cancelParticipation = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인 필요");

    const {challengeId, participationId} = data as {
      challengeId?: string;
      participationId?: string;
    };
    if (!challengeId || !participationId) {
      throw new HttpsError("invalid-argument", "잘못된 요청");
    }

    const db = admin.firestore();
    const chRef = db.collection("challenges").doc(challengeId);
    const partRef = db
      .collection("users")
      .doc(uid)
      .collection("participations")
      .doc(participationId);

    await db.runTransaction(async (tx) => {
      const part = await tx.get(partRef);
      if (!part.exists || part.get("completed")) return;

      const ch = await tx.get(chRef);
      const cur = (ch.get("participantsCount") as number) || 0;
      if (cur > 0) {
        tx.update(chRef, {participantsCount: cur - 1});
      }

      tx.delete(partRef);
    });

    return {success: true};
  }
);

/* ───────────────────── 5. 미완료 참여 자동 정리 ───────────────────── */
export const purgeUnfinishedParticipations = onSchedule(
  {
    region: "asia-northeast3",
    schedule: "every 15 minutes",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const db = admin.firestore();
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 15 * 60_000
    ); // 15분 전

    const snap = await db
      .collectionGroup("participations")
      .where("completed", "==", false)
      .where("createdAt", "<=", cutoff)
      .limit(5000)
      .get();
    if (snap.empty) return;

    const bw = db.bulkWriter();
    for (const d of snap.docs) {
      const cid = d.get("challengeId") as string | undefined;
      if (cid) {
        bw.update(db.collection("challenges").doc(cid), {
          participantsCount: admin.firestore.FieldValue.increment(-1),
        });
      }
      bw.delete(d.ref);
    }
    await bw.close();
    console.log(`[purgeUnfinished] removed=${snap.size}`);
  }
);

/* ───────────────────── 6. 연속 인증(필수 챌린지) 스탯 ───────────────────── */
export const onPostCreatedUpdateStreak = onDocumentCreated(
  {
    region: "asia-northeast3",
    document: "challengePosts/{postId}",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const uid = snap.get("userId") as string | undefined;
    const cid = snap.get("challengeId") as string | undefined;
    if (!uid || !cid) return;

    const chDoc = await admin.firestore()
      .collection("challenges")
      .doc(cid)
      .get();
    if (chDoc.get("type") !== "mandatory") return; // 필수 챌린지 전용

    const todayISO = DateTime.now()
      .setZone("Asia/Seoul")
      .toFormat("yyyy-MM-dd");

    const db = admin.firestore();
    const streakRef = db
      .collection("users")
      .doc(uid)
      .collection("streaks")
      .doc(cid);

    await db.runTransaction(async (tx) => {
      const cur = await tx.get(streakRef);
      let streak = 1;

      if (cur.exists) {
        const last = cur.get("lastDate") as string;
        const diff =
          DateTime.fromISO(todayISO).diff(DateTime.fromISO(last), "days").days;
        streak = diff === 0 || diff === 1 ?
          (cur.get("streakCount") as number) + 1 :
          1;
      }

      tx.set(
        streakRef,
        {
          streakCount: streak,
          lastDate: todayISO,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
      tx.update(snap.ref, {streakNum: streak});
    });

    /* 7·14·21…일마다 축하 Push */
    const now = (await streakRef.get()).get("streakCount") as number;
    if (now % 7 === 0) {
      const token = (
        await db.collection("users").doc(uid).get()
      ).get("fcmToken") as string | undefined;
      if (token) {
        await admin.messaging().send({
          token,
          notification: {
            title: `🔥 ${now}일 연속 인증!`,
            body: "기록을 이어가 보세요",
          },
          data: {
            type: "streak",
            challengeId: cid,
            streak: String(now),
          },
          android: {priority: "high"},
        });
      }
    }
  }
);

/* ───────────────────── 7. 오래된 챌린지·포스트 정리 ───────────────────── */
export const purgeOldChallenges = onSchedule(
  {
    region: "asia-northeast3",
    schedule: "every 1 hours",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();
    const cutoff = DateTime.now().minus({days: 7}).toJSDate();

    const expired = await db
      .collection("challenges")
      .where("endDate", "<=", cutoff)
      .get();
    const expiredIds = expired.docs.map((d) => d.id);

    const orphanIds = new Set<string>();
    const existsMap = new Map<string, boolean>();

    let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    while (true) {
      let q = db
        .collection("challengePosts")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(500);
      if (cursor) q = q.startAfter(cursor);

      const snap = await q.get();
      if (snap.empty) break;

      for (const d of snap.docs) {
        cursor = d;
        const cid = d.get("challengeId") as string;
        if (existsMap.has(cid)) {
          if (!existsMap.get(cid)) orphanIds.add(cid);
        } else {
          const exists = (await db.collection("challenges").doc(cid).get())
            .exists;
          existsMap.set(cid, exists);
          if (!exists) orphanIds.add(cid);
        }
      }
    }

    const targets = new Set([...expiredIds, ...orphanIds]);
    let chDel = 0;
    let postDel = 0;
    let fileDel = 0;

    for (const cid of targets) {
      while (true) {
        const ps = await db
          .collection("challengePosts")
          .where("challengeId", "==", cid)
          .limit(500)
          .get();
        if (ps.empty) break;

        const bw = db.bulkWriter();
        for (const p of ps.docs) {
          bw.delete(p.ref);
          postDel++;
          const url = p.get("imageUrl") as string | undefined;
          if (url?.includes("/o/")) {
            const gs = decodeURIComponent(
              url.split("/o/")[1]?.split("?")[0] || ""
            );
            try {
              await bucket.file(gs).delete();
              fileDel++;
            } catch (e) {
              console.warn(`[purgeOld] file delete failed: ${(e as Error).message}`);
            }
          }
        }
        await bw.close();
      }
      if ((await db.collection("challenges").doc(cid).get()).exists) {
        await db.collection("challenges").doc(cid).delete();
        chDel++;
      }
    }
    console.log(`[purgeOld] ch=${chDel} post=${postDel} file=${fileDel}`);
  }
);

/* ───────────────────── 8. 게시물 신고 + 자동삭제 ───────────────────── */
export const reportPost = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인 필요");

    const {postId} = data as { postId?: string };
    if (!postId) throw new HttpsError("invalid-argument", "postId 필수");

    const db = admin.firestore();
    const postRef = db.collection("challengePosts").doc(postId);
    const repRef = postRef.collection("reports").doc(uid);

    await db.runTransaction(async (tx) => {
      const postSnap = await tx.get(postRef);
      if (!postSnap.exists) throw new HttpsError("not-found", "이미 삭제");

      if ((await tx.get(repRef)).exists) {
        throw new HttpsError("already-exists", "중복 신고");
      }
      tx.set(repRef, {createdAt: FieldValue.serverTimestamp()});

      // 🔸 최초 신고 여부와 상관없이 flagged
      if (postSnap.data()?.reported !== true) {
        tx.update(postRef, {reported: true});
      }
    });

    return {success: true};
  }
);

// functions/onPostReportCreated.ts -------------------------------------
export const onPostReportCreated = onDocumentCreated(
  {
    region: "asia-northeast3",
    document: "challengePosts/{postId}/reports/{uid}",
  },
  async (event) => {
    const {postId, uid: reporter} = event.params;
    const db = admin.firestore();

    /* 🔹 reports 개수 확인 */
    const repCntSnapshot = await db
      .collection("challengePosts")
      .doc(postId)
      .collection("reports")
      .count()
      .get();
    const repCnt = repCntSnapshot.data().count;

    /* 🔔 “첫 번째 신고” → 관리자 Push */
    if (repCnt === 1) {
      await admin.messaging().send({
        topic: "admin",
        notification: {
          title: "🚨 새 게시물 신고",
          body: `게시물 ${postId} 에 신고가 접수되었습니다.`,
        },
        data: {type: "postReport", postId, reporter},
        apns: {payload: {aps: {sound: "default"}}, headers: {"apns-priority": "10"}},
        android: {priority: "high"},
      });
    }

    /* 🔥 10회 이상 → 자동 삭제 */
    if (repCnt >= 10) {
      const postRef = db.collection("challengePosts").doc(postId);
      await postRef.delete();
    }
  }
);


/* ───────────────────── 9. 새로운 챌린지 Push ───────────────────── */
export const sendNewChallengePush = onDocumentCreated(
  {
    region: "asia-northeast3",
    document: "challenges/{cid}",
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    await admin.messaging().send({
      topic: "new-challenge",
      notification: {
        title: String(data.title ?? "새 챌린지!"),
        body: String(data.description ?? ""),
      },
      data: {type: "challenge", challengeId: event.params.cid},
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });

    console.log(`[sendNewChallengePush] ${event.params.cid} sent`);
  }
);

/* ───────────────────── 10. 아이디어 아카이브 시 완전 삭제 ───────────────────── */
export const onChallengeIdeaArchived = onDocumentUpdated(
  {
    region: "asia-northeast3",
    document: "challengeIdeas/{id}",
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;
    if (before?.isArchived === false && after.isArchived === true) {
      await admin.firestore()
        .collection("challengeIdeas")
        .doc(event.params.id)
        .delete();
    }
  }
);
/* ───────────────────── 12. 댓글 작성  ───────────────────── */
export const createComment = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인 필요");

    const {postId, commentId, text} = data as {
      postId?: string;
      commentId?: string;
      text?: string;
    };
    if (!postId || !commentId || !text) {
      throw new HttpsError("invalid-argument", "postId/commentId/text 필수");
    }

    const body = String(text).trim();
    if (body.length === 0 || body.length > 300) {
      throw new HttpsError("invalid-argument", "1–300자");
    }
    if (containsBadWords(body)) {
      throw new HttpsError("failed-precondition", "부적절한 표현");
    }

    const db = admin.firestore();
    const postRef = db.collection("challengePosts").doc(postId);
    const cmtRef = postRef.collection("comments").doc(commentId);

    await db.runTransaction(async (tx) => {
      const post = await tx.get(postRef);
      if (!post.exists) {
        throw new HttpsError("not-found", "포스트 없음");
      }
      if (post.get("reported") === true) {
        throw new HttpsError("failed-precondition", "신고되어 잠김");
      }

      if ((await tx.get(cmtRef)).exists) {
        throw new HttpsError("already-exists", "중복 commentId");
      }

      tx.set(cmtRef, {
        userId: uid,
        text: body,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        reactions: {},
        reported: false,
      });
      tx.update(postRef, {
        commentsCount: admin.firestore.FieldValue.increment(1),
      });
    });

    return {success: true};
  }
);

/* ───────────────────── 13. 댓글 신고 + 자동삭제 ───────────────────── */
export const reportComment = onCall(
  {region: "asia-northeast3"},
  async ({auth, data}) => {
    /* ─── 0. 파라미터 확인 ───────────────────────────── */
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인 필요");

    const {postId, commentId} = data as {
      postId?: string;
      commentId?: string;
    };
    if (!postId || !commentId) {
      throw new HttpsError("invalid-argument", "postId / commentId 필수");
    }

    /* ─── 1. 참조 준비 ──────────────────────────────── */
    const db = admin.firestore();
    const cmtRef = db
      .collection("challengePosts")
      .doc(postId)
      .collection("comments")
      .doc(commentId);

    const repRef = cmtRef.collection("reports").doc(uid);

    /* ─── 2. 트랜잭션 수행 ──────────────────────────── */
    await db.runTransaction(async (tx) => {
      const cmtSnap = await tx.get(cmtRef);
      if (!cmtSnap.exists) throw new HttpsError("not-found", "이미 삭제된 댓글");

      if ((await tx.get(repRef)).exists) {
        throw new HttpsError("already-exists", "중복 신고");
      }

      // 신고 서브문서 생성
      tx.set(repRef, {createdAt: FieldValue.serverTimestamp()});

      // 댓글 문서에 reported:true (이미 true 라면 그대로 유지)
      if (cmtSnap.data()?.reported !== true) {
        tx.update(cmtRef, {reported: true});
      }
    });

    return {success: true};
  }
);

// functions/onCommentReportCreated.ts ----------------------------------
export const onCommentReportCreated = onDocumentCreated(
  {
    region: "asia-northeast3",
    document: "challengePosts/{postId}/comments/{commentId}/reports/{uid}",
  },
  async (event) => {
    const {postId, commentId, uid: reporter} = event.params;
    const db = admin.firestore();

    const repCntSnapshot = await db
      .collection("challengePosts").doc(postId)
      .collection("comments").doc(commentId)
      .collection("reports")
      .count().get();
    const repCnt = repCntSnapshot.data().count;

    if (repCnt === 1) {
      await admin.messaging().send({
        topic: "admin",
        notification: {
          title: "🚨 새 댓글 신고",
          body: `댓글 ${commentId} 에 신고가 접수되었습니다.`,
        },
        data: {type: "commentReport", postId, commentId, reporter},
        apns: {payload: {aps: {sound: "default"}}, headers: {"apns-priority": "10"}},
        android: {priority: "high"},
      });
    }

    if (repCnt >= 10) {
      const cmtRef = db.collection("challengePosts").doc(postId)
        .collection("comments").doc(commentId);
      await cmtRef.delete();
    }
  }
);


/* ───────────────────── 14. 오픈 챌린지 참여 횟수 ───────────────────── */
export const onPostCreatedUpdateOpenCount = onDocumentCreated(
  {
    region: "asia-northeast3",
    document: "challengePosts/{postId}",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const uid = snap.get("userId") as string | undefined;
    const cid = snap.get("challengeId") as string | undefined;
    if (!uid || !cid) return;

    const chDoc = await admin
      .firestore()
      .collection("challenges")
      .doc(cid)
      .get();
    if (chDoc.get("type") !== "open") return;

    const db = admin.firestore();
    const cntRef = db
      .collection("users")
      .doc(uid)
      .collection("openCounts")
      .doc(cid);

    const next = await db.runTransaction(async (tx) => {
      const cur = await tx.get(cntRef);
      const current = (cur.get("count") as number | undefined) ?? 0;
      const nxt = current + 1;
      tx.set(
        cntRef,
        {
          count: nxt,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
      tx.update(snap.ref, {openCountNum: nxt});
      return nxt;
    });

    if ([10, 25, 50, 100].includes(next)) {
      const token = (
        await db.collection("users").doc(uid).get()
      ).get("fcmToken") as string | undefined;
      if (token) {
        await admin.messaging().send({
          token,
          notification: {
            title: `🏅 ${next}회 참여 달성!`,
            body: "오픈 챌린지 기여를 이어가 보세요",
          },
          data: {type: "openCount", challengeId: cid, count: String(next)},
          android: {priority: "high"},
        });
      }
    }
  }
);

/* ───────────────────── 15. SafeSearch 관련 내보내기 ───────────────────── */
export {safeSearchScan} from "./safeSearchScan";
export {safeSearchOnPostCreated} from "./safeSearchOnPostCreated";
