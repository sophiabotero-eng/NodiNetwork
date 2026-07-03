import { FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { db, messaging } from "./admin";

type NotificationKind =
  | "newFollower"
  | "connectionRequest"
  | "connectionAccepted"
  | "newMessage"
  | "mention"
  | "eventInvite"
  | "recommendation";

interface NotificationInput {
  kind: NotificationKind;
  actorId: string;
  actorDisplayName: string;
  actorPhotoURL: string | null;
  message: string;
  deepLinkURL?: string;
}

/** Writes to `users/{uid}/notifications/{id}` — matches NodiNotification.swift. */
export async function writeNotification(uid: string, input: NotificationInput): Promise<void> {
  await db.collection("users").doc(uid).collection("notifications").add({
    ...input,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

interface PushPayload {
  title: string;
  body: string;
  deepLinkURL?: string;
}

/** Best-effort push — a user with no registered devices simply gets nothing. */
export async function sendPushToUser(uid: string, payload: PushPayload): Promise<void> {
  const userSnap = await db.collection("users").doc(uid).get();
  const tokens = (userSnap.data()?.fcmTokens as string[] | undefined) ?? [];
  if (tokens.length === 0) return;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: { title: payload.title, body: payload.body },
    data: payload.deepLinkURL ? { deepLinkURL: payload.deepLinkURL } : {},
    apns: { payload: { aps: { sound: "default" } } },
  });

  const staleTokens = response.responses
    .map((result, index) => (result.success ? null : tokens[index]))
    .filter((token): token is string => token !== null);

  if (staleTokens.length > 0) {
    logger.info(`Removing ${staleTokens.length} stale FCM token(s) for ${uid}`);
    await db.collection("users").doc(uid).update({
      fcmTokens: FieldValue.arrayRemove(...staleTokens),
    });
  }
}
