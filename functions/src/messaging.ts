import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "./admin";
import { sendPushToUser } from "./notifications";

/**
 * `unreadCounts` on the conversation doc is otherwise freely writable by
 * either participant (see firestore.rules comment) for the cosmetic
 * "mark read" case, but the *increment* on send specifically needs to be
 * server-side — two devices sending at once would otherwise race a
 * client-computed `unreadCounts[recipient] + 1`.
 */
export const onMessageCreated = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const conversationId = event.params.conversationId;
    const conversationSnap = await db.collection("conversations").doc(conversationId).get();
    const conversation = conversationSnap.data();
    if (!conversation) return;

    const senderId = message.senderId as string;
    const recipientId = (conversation.participantIds as string[]).find((id) => id !== senderId);
    if (!recipientId) return;

    await db.collection("conversations").doc(conversationId).update({
      [`unreadCounts.${recipientId}`]: FieldValue.increment(1),
    });

    const sender = conversation.participants?.[senderId];
    if (!sender) return;

    const preview = message.type === "voice" ? "🎤 Voice message" : (message.text as string) ?? "";
    await sendPushToUser(recipientId, {
      title: sender.displayName ?? "New message",
      body: preview,
      deepLinkURL: `nodi://profile/${sender.username}`,
    });
  }
);
