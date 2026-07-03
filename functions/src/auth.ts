import { onUserDeleted } from "firebase-functions/v2/identity";
import { logger } from "firebase-functions/v2";
import { db, storage } from "./admin";

/**
 * Firebase Auth doesn't know anything about Firestore or Storage, so when a
 * user deletes their account (SettingsView -> AuthService.deleteAccount(),
 * which only calls `FirebaseAuth.User.delete()`), this trigger cleans up
 * everything else: the user document, their reserved username, their
 * notifications subcollection, and their uploaded media.
 */
export const cleanupDeletedUser = onUserDeleted(async (event) => {
  const uid = event.data.uid;
  logger.info(`Cleaning up data for deleted user ${uid}`);

  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  const username = userSnap.data()?.username as string | undefined;

  const batch = db.batch();

  if (username) {
    batch.delete(db.collection("usernames").doc(username.toLowerCase()));
  }

  const notifications = await userRef.collection("notifications").listDocuments();
  notifications.forEach((doc) => batch.delete(doc));

  batch.delete(userRef);
  await batch.commit();

  await Promise.allSettled([
    deleteFolder(`profile_photos/${uid}`),
    deleteFolder(`cover_images/${uid}`),
    deleteFolder(`project_media/images/${uid}`),
    deleteFolder(`project_media/videos/${uid}`),
    deleteFolder(`project_media/documents/${uid}`),
    deleteFolder(`voice_messages/${uid}`),
  ]);
});

async function deleteFolder(prefix: string): Promise<void> {
  const bucket = storage.bucket();
  await bucket.deleteFiles({ prefix }).catch((error) => {
    logger.warn(`Failed to delete storage prefix ${prefix}`, error);
  });
}
