import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "./admin";

interface Candidate {
  id: string;
  displayName: string;
  username: string;
  profilePhotoURL?: string | null;
  profession: string;
  location: string;
  softwareUsed: string[];
}

/**
 * A real, documented scoring heuristic — not a call to a hosted LLM. This
 * repo has no API keys/inference budget configured, and "AI
 * recommendations" for a cold-start social graph is much more reliably
 * served by transparent, explainable signals (shared tools, same city,
 * mutual connections) than by an LLM guessing at compatibility from a
 * bio. Swapping this for a model-based recommender is a reasonable
 * follow-up once there's real engagement data to train/rank against —
 * see README.
 */
function scoreCandidate(viewer: Candidate, candidate: Candidate, mutualCount: number): { score: number; reasons: string[] } {
  let score = 0;
  const reasons: string[] = [];

  const sharedSoftware = candidate.softwareUsed.filter((tool) => viewer.softwareUsed.includes(tool));
  if (sharedSoftware.length > 0) {
    score += sharedSoftware.length * 8;
    reasons.push(`Also uses ${sharedSoftware.slice(0, 2).join(", ")}`);
  }

  if (viewer.profession && candidate.profession && viewer.profession.toLowerCase() === candidate.profession.toLowerCase()) {
    score += 15;
    reasons.push(`Also works as a ${candidate.profession}`);
  }

  if (viewer.location && candidate.location && viewer.location.toLowerCase() === candidate.location.toLowerCase()) {
    score += 10;
    reasons.push(`Based in ${candidate.location}`);
  }

  if (mutualCount > 0) {
    score += Math.min(mutualCount, 5) * 12;
    reasons.push(mutualCount === 1 ? "1 mutual connection" : `${mutualCount} mutual connections`);
  }

  return { score, reasons };
}

async function generateRecommendationsFor(uid: string): Promise<void> {
  const viewerSnap = await db.collection("users").doc(uid).get();
  const viewerData = viewerSnap.data();
  if (!viewerData) return;
  const viewer: Candidate = {
    id: uid,
    displayName: viewerData.displayName ?? "",
    username: viewerData.username ?? "",
    profession: viewerData.profession ?? "",
    location: viewerData.location ?? "",
    softwareUsed: viewerData.softwareUsed ?? [],
  };

  const connectionsSnap = await db.collection("connections")
    .where("participantIds", "array-contains", uid)
    .where("status", "==", "accepted")
    .get();

  const connectedIds = new Set<string>();
  const neighborsOfConnections = new Map<string, number>(); // candidateId -> mutual count
  connectionsSnap.forEach((doc) => {
    const participantIds = doc.data().participantIds as string[];
    const otherId = participantIds.find((id) => id !== uid);
    if (otherId) connectedIds.add(otherId);
  });

  // Mutual-connection counts: for each of the viewer's connections, look
  // at *their* connections and tally how often each candidate shows up.
  // Capped to the viewer's first 25 connections to bound read volume.
  const sampledConnectionIds = Array.from(connectedIds).slice(0, 25);
  for (const connectionId of sampledConnectionIds) {
    const theirConnections = await db.collection("connections")
      .where("participantIds", "array-contains", connectionId)
      .where("status", "==", "accepted")
      .get();
    theirConnections.forEach((doc) => {
      const participantIds = doc.data().participantIds as string[];
      const candidateId = participantIds.find((id) => id !== connectionId);
      if (candidateId && candidateId !== uid && !connectedIds.has(candidateId)) {
        neighborsOfConnections.set(candidateId, (neighborsOfConnections.get(candidateId) ?? 0) + 1);
      }
    });
  }

  const candidatePool = await db.collection("users")
    .orderBy("lastActiveAt", "desc")
    .limit(150)
    .get();

  const scored: { candidate: Candidate; score: number; reasons: string[] }[] = [];
  candidatePool.forEach((doc) => {
    if (doc.id === uid || connectedIds.has(doc.id)) return;
    const data = doc.data();
    const candidate: Candidate = {
      id: doc.id,
      displayName: data.displayName ?? "",
      username: data.username ?? "",
      profilePhotoURL: data.profilePhotoURL ?? null,
      profession: data.profession ?? "",
      location: data.location ?? "",
      softwareUsed: data.softwareUsed ?? [],
    };
    const mutualCount = neighborsOfConnections.get(doc.id) ?? 0;
    const { score, reasons } = scoreCandidate(viewer, candidate, mutualCount);
    if (score > 0) scored.push({ candidate, score, reasons });
  });

  scored.sort((a, b) => b.score - a.score);
  const top = scored.slice(0, 20);

  const recommendationsRef = db.collection("users").doc(uid).collection("recommendations");
  const existing = await recommendationsRef.get();
  const batch = db.batch();
  existing.forEach((doc) => batch.delete(doc.ref));
  top.forEach(({ candidate, score, reasons }) => {
    batch.set(recommendationsRef.doc(candidate.id), {
      candidateId: candidate.id,
      displayName: candidate.displayName,
      username: candidate.username,
      profilePhotoURL: candidate.profilePhotoURL ?? null,
      profession: candidate.profession,
      score,
      reasons,
      computedAt: new Date(),
    });
  });
  await batch.commit();
}

export const recomputeRecommendations = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to get recommendations.");
  }
  await generateRecommendationsFor(request.auth.uid);
  return { success: true };
});

export const onConnectionAcceptedRefreshRecommendations = onDocumentUpdated("connections/{connectionId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.status !== "pending" || after.status !== "accepted") return;

  const participantIds = after.participantIds as string[];
  await Promise.all(participantIds.map((uid) => generateRecommendationsFor(uid)));
});
