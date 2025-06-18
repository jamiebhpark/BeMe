/* eslint-disable @typescript-eslint/no-empty-function */
/* eslint-disable max-len */
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentCreated} from "firebase-functions/firestore";
import * as admin from "firebase-admin";
admin.initializeApp();

/**
 * Cloud Functions for **BeMe Challenge**
 * ────────────────────────────────────────────────────────────────
 * 1. participateChallenge      – 챌린지 참여 트랜잭션 (+ participationId 리턴)   ✅ NEW
 * 2. createPost                – 새 포스트 업로드 (+ participationId 바인딩)     ✅ NEW
 * 3. cancelParticipation       – 참여 취소 onCall                                 ✅ NEW
 * 4. purgeUnfinishedParticipations – 5 분마다 미완료 참여 정리                    ✅ NEW
 * 5. 기타 기존 기능 (purgeOldChallenges, 신고, Push 등)
 */

/* ──────────────────────────────────────────────
 | 1) 챌린지 참여
 ────────────────────────────────────────────── */
export const participateChallenge = onCall(
  {region: "asia-northeast3"},
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

    const {challengeId, type} = req.data as {
      challengeId: string; type: string;
    };
    if (!challengeId || !type) {
      throw new HttpsError("invalid-argument", "잘못된 요청입니다.");
    }

    const db = admin.firestore();

    // 필수 챌린지 중복 검사 – completed == true 인 것만 체크
    if (type === "필수") {
      const startOfDay = admin.firestore.Timestamp.fromDate(
        new Date(new Date().setHours(0, 0, 0, 0)),
      );
      const dupSnap = await db
        .collection("users").doc(uid)
        .collection("participations")
        .where("challengeId", "==", challengeId)
        .where("createdAt", ">=", startOfDay)
        .where("completed", "==", true) // ✅ 추가
        .get();

      if (!dupSnap.empty) {
        throw new HttpsError("failed-precondition", "오늘 이미 참여하셨습니다.");
      }
    }

    /* 트랜잭션 */
    const chRef = db.collection("challenges").doc(challengeId);
    const partRef = db
      .collection("users").doc(uid)
      .collection("participations")
      .doc(); // ▶️ 랜덤 ID

    await db.runTransaction(async (tx) => {
      const ch = await tx.get(chRef);
      if (!ch.exists) throw new HttpsError("not-found", "챌린지를 찾을 수 없습니다.");

      tx.update(chRef, {
        participantsCount: admin.firestore.FieldValue.increment(1),
      });
      tx.set(partRef, {
        challengeId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        completed: false, // ▶️ 미완료 플래그
      });
    });

    /* ▶️ 클라이언트에서 필요 - participationId 반환 */
    return {success: true, participationId: partRef.id}; // ✅ NEW
  },
);

/* ──────────────────────────────────────────────
 | 2) 새 포스트 업로드 (이미지 URL + 캡션 + participationId)
 ────────────────────────────────────────────── */
export const createPost = onCall(
  {region: "asia-northeast3"},
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

    const {challengeId, imageUrl, caption, participationId} = req.data as {
      challengeId: string; imageUrl: string; caption?: string;
      participationId?: string; // ▶️ optional
    };

    if (!challengeId || !imageUrl) {
      throw new HttpsError("invalid-argument", "필수 값 누락");
    }
    if (caption && caption.length > 80) {
      throw new HttpsError("invalid-argument", "캡션은 80자 이하만 입력해 주세요.");
    }
    if (caption && containsBadWords(caption)) {
      throw new HttpsError("failed-precondition", "부적절한 표현이 포함돼 있습니다.");
    }

    const db = admin.firestore();

    /* 1) Post 생성 */
    await db.collection("challengePosts").add({
      challengeId,
      userId: uid,
      imageUrl,
      caption: caption ?? null,
      participationId: participationId ?? null, // ✅ NEW
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      reactions: {},
      reported: false,
    });

    /* 2) 참여 완료 플래그 업데이트 */
    if (participationId) {
      const partRef = db.collection("users").doc(uid)
        .collection("participations").doc(participationId);
      await partRef.update({completed: true});
    }

    return {success: true};
  },
);

/* ──────────────────────────────────────────────
 | 3) 참여 취소  (사용자 타이머 만료·수동 취소)
 ────────────────────────────────────────────── */
export const cancelParticipation = onCall(
  {region: "asia-northeast3"},
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

    const {challengeId, participationId} = req.data as {
      challengeId: string; participationId: string;
    };
    if (!challengeId || !participationId) {
      throw new HttpsError("invalid-argument", "잘못된 요청입니다.");
    }

    const db = admin.firestore();
    const chRef = db.collection("challenges").doc(challengeId);
    const partRef = db.collection("users").doc(uid)
      .collection("participations").doc(participationId);

    await db.runTransaction(async (tx) => {
      const part = await tx.get(partRef);
      if (!part.exists) return; // 이미 없으면 no-op
      if (part.get("completed") === true) return; // 완료된 건 touch X

      tx.delete(partRef);
      tx.update(chRef, {
        participantsCount: admin.firestore.FieldValue.increment(-1),
      });
    });

    return {success: true};
  },
);

/* ──────────────────────────────────────────────
 | 4) 5분마다 미완료 참여 정리
 ────────────────────────────────────────────── */
export const purgeUnfinishedParticipations = onSchedule(
  {
    region: "asia-northeast3",
    schedule: "every 5 minutes",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const db = admin.firestore();
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 5 * 60 * 1_000, // 5 분 전
    );

    // 1) users/*/participations 스캔  ←←★ 수정된 주석
    const users = await db.collection("users").listDocuments();

    for (const uRef of users) {
      const partsSnap = await uRef.collection("participations")
        .where("createdAt", "<=", cutoff)
        .where("completed", "==", false)
        .limit(50)
        .get();

      if (partsSnap.empty) continue;

      const batch = db.batch();
      for (const p of partsSnap.docs) {
        const cid = p.get("challengeId") as string | undefined;
        if (cid) {
          const chRef = db.collection("challenges").doc(cid);
          batch.update(chRef, {
            participantsCount: admin.firestore.FieldValue.increment(-1),
          });
        }
        batch.delete(p.ref);
      }
      await batch.commit();
      console.log(`[purgeUnfinished] uid=${uRef.id} removed=${partsSnap.size}`);
    }
  },
);

/* ──────────────────────────────────────────────
 | 5) 욕설 필터 util
 ────────────────────────────────────────────── */

/**
 * 텍스트에 금칙어가 포함돼 있는지 여부를 반환한다.
 *
 * @param {string} text  검사할 문자열
 * @return {boolean}     금칙어 포함 시 `true`
 */
function containsBadWords(text: string): boolean {
  const bad: string[] = [
    "시발", "씨발", "ㅅㅂ", "좆", "존나",
    "fuck", "shit", "bitch", "asshole", "fucking",
  ];
  const lower = text.toLowerCase();
  return bad.some((w) => lower.includes(w));
}

/* 6) 아래 ↓ 기존 purgeOldChallenges / 신고 / Push 함수들은 그대로 유지 */

/* ──────────────────────────────────────────────
 | 3) 종료 + 7일 경과 챌린지 파기 & 포스트 삭제
 |    크론: 매 1시간
 ────────────────────────────────────────────── */

/* ──────────────────────────────────────────────
 | purgeOldChallenges – asia-northeast3 (v2)
 | 매 1시간 : endDate + 7d 경과 챌린지 → 포스트+이미지+챌린지 문서 삭제
 ────────────────────────────────────────────── */
export const purgeOldChallenges = onSchedule(
  {
    region: "asia-northeast3",
    schedule: "every 1 hours",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();
    const cutoff = new Date(Date.now() - 7 * 86_400 * 1_000); // 7일 전

    /* ---------- 1) endDate + 7일 경과 챌린지 목록 --------- */
    const oldChSnap = await db.collection("challenges")
      .where("endDate", "<=", cutoff)
      .get();
    const expiredIds = oldChSnap.docs.map((d) => d.id);

    /* ---------- 2) orphan posts 찾기 ----------------------- */
    // (posts 500개씩 스캔 → set 에 담아가며 orphan pick)
    const orphanIds: Set<string> = new Set();
    const knownMap: Map<string, boolean> = new Map(); // challengeId → 존재여부 캐시
    let start: FirebaseFirestore.QueryDocumentSnapshot | undefined;

    // eslint-disable-next-line no-constant-condition
    while (true) {
      let q = db.collection("challengePosts").orderBy(admin.firestore.FieldPath.documentId()).limit(500);
      if (start) q = q.startAfter(start);

      const snap = await q.get();
      if (snap.empty) break;

      for (const d of snap.docs) {
        start = d;
        const cid = d.get("challengeId") as string;
        if (knownMap.has(cid)) {
          if (!knownMap.get(cid)) orphanIds.add(cid);
        } else {
          // Firestore Doc Cache miss ‑ 직접 조회
          const exists = (await db.collection("challenges").doc(cid).get()).exists;
          knownMap.set(cid, exists);
          if (!exists) orphanIds.add(cid);
        }
      }
    }

    /* ---------- 3) 삭제 실행 ------------------------------ */
    const targetIds = new Set([...expiredIds, ...orphanIds]);

    let chDel = 0; let postDel = 0; let fileDel = 0;

    for (const cid of targetIds) {
      /* 3‑1) 포스트 500 단위 삭제 */
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const pSnap = await db.collection("challengePosts")
          .where("challengeId", "==", cid)
          .limit(500).get();
        if (pSnap.empty) break;

        const batch = db.batch();
        for (const p of pSnap.docs) {
          batch.delete(p.ref);
          postDel++;

          // storage 지우기
          const url = p.get("imageUrl") as string | undefined;
          if (url?.includes("/o/")) {
            const encoded = url.split("/o/")[1]?.split("?")[0] ?? "";
            const gsPath = decodeURIComponent(encoded); // user_uploads/UID/CID/…
            try {
              await bucket.file(gsPath).delete(); fileDel++;
            } catch {/* ignore */}
          }
        }
        await batch.commit();
      }

      /* 3‑2) 챌린지 문서 삭제(있다면) */
      const chRef = db.collection("challenges").doc(cid);
      const chDoc = await chRef.get();
      if (chDoc.exists) {
        await chRef.delete(); chDel++;
      }
    }

    console.log(`[purge] ch=${chDel} post=${postDel} file=${fileDel}`);
  },
);
// ──────────────────────────────────────────────
// 4)  신고 처리  (onCall + onCreate trigger)
// ──────────────────────────────────────────────
export const reportPost = onCall(
  {region: "asia-northeast3"},
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

    const {postId} = req.data as { postId: string };
    if (!postId) throw new HttpsError("invalid-argument", "postId 필수");

    const db = admin.firestore();
    const post = db.collection("challengePosts").doc(postId);
    const rep = post.collection("reports").doc(uid);

    // 트랜잭션: 중복 체크 → 신고 문서 생성
    try {
      await db.runTransaction(async (tx) => {
        const already = await tx.get(rep);
        if (already.exists) {
          throw new HttpsError("already-exists", "이미 신고한 게시물입니다.");
        }
        tx.set(rep, {createdAt: admin.firestore.FieldValue.serverTimestamp()});
      });
      return {success: true};
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("unknown", (e as Error).message);
    }
  },
);

/* ---- sub-collection onCreate trigger ---- */
export const onReportCreated = onDocumentCreated(
  {
    region: "asia-northeast3",
    document: "challengePosts/{postId}/reports/{uid}",
  },
  async (event) => {
    const postId = event.params.postId;
    const db = admin.firestore();
    const post = db.collection("challengePosts").doc(postId);

    // 신고 개수 집계
    const reps = await post.collection("reports").count().get();
    if (reps.data().count >= 10) {
      // ① challengePosts 삭제
      await post.delete();

      // ② Storage 이미지도 삭제
      const url = event.data?.get("imageUrl") ?? null; // post 문서가 이미 삭제되면 null 이 될 수 있어 방어 코드
      if (typeof url === "string" && url.includes("/o/")) {
        const encoded = url.split("/o/")[1]?.split("?")[0] ?? "";
        const gsPath = decodeURIComponent(encoded);
        await admin.storage().bucket().file(gsPath).delete().catch(() => {});
      }
    }
  },
);
/* ─── 새 챌린지 → 푸시 알림 ───────────────────────── */
export const sendNewChallengePush = onDocumentCreated(
  {
    region: "asia-northeast3",
    document: "challenges/{cid}",
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const title = String(data.title ?? "새 챌린지!");
    const body = String(data.description ?? "");

    await admin.messaging().send({
      topic: "new-challenge", // 👆 모든 유저가 구독
      notification: {title, body},
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
      data: {type: "challenge", challengeId: event.params.cid},
    });

    console.log(`[sendNewChallengePush] ${event.params.cid} sent`);
  },
);

