import { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "./admin";
import { sendPushToUser, writeNotification } from "./notifications";

/**
 * A `follows/{followId}` doc is created client-side (FollowRepository.follow).
 * `followerCount`/`followingCount` on `users/{uid}` are locked out of
 * client writes by firestore.rules specifically so this function is the
 * only place they change — see firestore.rules comments.
 */
export const onFollowCreated = onDocumentCreated("follows/{followId}", async (event) => {
  const follow = event.data?.data();
  if (!follow) return;

  const { followerId, followingId } = follow as { followerId: string; followingId: string };

  await Promise.all([
    db.collection("users").doc(followerId).update({ followingCount: FieldValue.increment(1) }),
    db.collection("users").doc(followingId).update({ followerCount: FieldValue.increment(1) }),
  ]);

  const followerSnap = await db.collection("users").doc(followerId).get();
  const follower = followerSnap.data();
  if (!follower) return;

  await writeNotification(followingId, {
    kind: "newFollower",
    actorId: followerId,
    actorDisplayName: follower.displayName ?? "",
    actorPhotoURL: follower.profilePhotoURL ?? null,
    message: `${follower.displayName} started following you.`,
    deepLinkURL: `nodi://profile/${follower.username}`,
  });

  await sendPushToUser(followingId, {
    title: "New follower",
    body: `${follower.displayName} started following you.`,
  });
});

export const onFollowDeleted = onDocumentDeleted("follows/{followId}", async (event) => {
  const follow = event.data?.data();
  if (!follow) return;

  const { followerId, followingId } = follow as { followerId: string; followingId: string };

  await Promise.all([
    db.collection("users").doc(followerId).update({ followingCount: FieldValue.increment(-1) }),
    db.collection("users").doc(followingId).update({ followerCount: FieldValue.increment(-1) }),
  ]);
});

/**
 * `connections/{connectionId}` documents are created directly with
 * `status: 'accepted'` for NFC-sourced connections, or `status: 'pending'`
 * for everything else (see ConnectionRepository.request). This trigger
 * fires on *creation*, so it only needs to handle the "created already
 * accepted" (NFC) case — the pending -> accepted transition is handled by
 * `onConnectionUpdated` below.
 */
export const onConnectionCreated = onDocumentCreated("connections/{connectionId}", async (event) => {
  const connection = event.data?.data();
  if (!connection) return;

  if (connection.status === "accepted") {
    await incrementConnectionCounts(connection.participantIds);
  }

  const requestedBy = connection.requestedBy as string;
  const recipientId = (connection.participantIds as string[]).find((id) => id !== requestedBy);
  if (!recipientId) return;

  const requester = connection.participants?.[requestedBy];
  if (!requester) return;

  if (connection.status === "pending") {
    await writeNotification(recipientId, {
      kind: "connectionRequest",
      actorId: requestedBy,
      actorDisplayName: requester.displayName ?? "",
      actorPhotoURL: requester.photoURL ?? null,
      message: `${requester.displayName} wants to connect with you.`,
      deepLinkURL: `nodi://profile/${requester.username}`,
    });
    await sendPushToUser(recipientId, {
      title: "New connection request",
      body: `${requester.displayName} wants to connect with you.`,
    });
  } else {
    // NFC auto-connect: tell the other participant it happened.
    await writeNotification(recipientId, {
      kind: "connectionAccepted",
      actorId: requestedBy,
      actorDisplayName: requester.displayName ?? "",
      actorPhotoURL: requester.photoURL ?? null,
      message: `You're now connected with ${requester.displayName}.`,
      deepLinkURL: `nodi://profile/${requester.username}`,
    });
  }
});

export const onConnectionUpdated = onDocumentUpdated("connections/{connectionId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  if (before.status === "pending" && after.status === "accepted") {
    await incrementConnectionCounts(after.participantIds);

    const requestedBy = after.requestedBy as string;
    const accepterId = (after.participantIds as string[]).find((id: string) => id !== requestedBy);
    if (!accepterId) return;
    const accepter = after.participants?.[accepterId];
    if (!accepter) return;

    await writeNotification(requestedBy, {
      kind: "connectionAccepted",
      actorId: accepterId,
      actorDisplayName: accepter.displayName ?? "",
      actorPhotoURL: accepter.photoURL ?? null,
      message: `${accepter.displayName} accepted your connection request.`,
      deepLinkURL: `nodi://profile/${accepter.username}`,
    });
    await sendPushToUser(requestedBy, {
      title: "Connection accepted",
      body: `${accepter.displayName} accepted your connection request.`,
    });
  }
});

async function incrementConnectionCounts(participantIds: string[]): Promise<void> {
  await Promise.all(
    participantIds.map((uid) => db.collection("users").doc(uid).update({ connectionCount: FieldValue.increment(1) }))
  );
}
