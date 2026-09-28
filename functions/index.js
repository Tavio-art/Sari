/**
 * Cloud Functions for Sari push notifications.
 *
 * Deploy: `firebase deploy --only functions`
 *
 * Client stores FCM tokens at:
 *   users/{uid}.fcmToken
 *   users/{uid}.fcmTokens.{token}
 * and the push preference at:
 *   users/{uid}.settings.push
 *
 * Call `sendPushToUser` (HTTPS callable) with:
 *   { uid, title, body, type?: 'payment'|'lowStock'|'creditOverdue'|'orderReady' }
 *
 * Or POST /sendPushHttp with the same JSON body + Authorization header
 * (for server-to-server; protect with your own secret in production).
 */

const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/https");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

setGlobalOptions({maxInstances: 10});

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Collect FCM tokens for a user and send a data+notification message.
 * Respects users/{uid}.settings.push === false.
 */
async function sendToUser({uid, title, body, type = "payment"}) {
  if (!uid || !title) {
    throw new Error("uid and title are required");
  }

  const userRef = admin.firestore().collection("users").doc(uid);
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new Error("User not found");
  }

  const data = snap.data() || {};
  const settings = data.settings || {};
  if (settings.push === false) {
    logger.info("Push disabled for user", {uid});
    return {sent: 0, reason: "push_disabled"};
  }

  const tokens = new Set();
  if (typeof data.fcmToken === "string" && data.fcmToken) {
    tokens.add(data.fcmToken);
  }
  if (data.fcmTokens && typeof data.fcmTokens === "object") {
    for (const key of Object.keys(data.fcmTokens)) {
      if (key) tokens.add(key);
    }
  }

  if (tokens.size === 0) {
    return {sent: 0, reason: "no_tokens"};
  }

  const message = {
    notification: {title, body: body || ""},
    data: {
      type: String(type),
      title: String(title),
      body: String(body || ""),
    },
    android: {
      notification: {channelId: "sari_alerts"},
    },
    tokens: [...tokens],
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  logger.info("Push sent", {
    uid,
    success: response.successCount,
    failure: response.failureCount,
  });

  // Drop invalid tokens.
  const stale = [];
  response.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error && r.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        stale.push([...tokens][i]);
      }
    }
  });
  if (stale.length) {
    const updates = {};
    for (const t of stale) {
      updates[`fcmTokens.${t}`] = admin.firestore.FieldValue.delete();
      if (data.fcmToken === t) updates.fcmToken = admin.firestore.FieldValue.delete();
    }
    await userRef.update(updates);
  }

  return {
    sent: response.successCount,
    failed: response.failureCount,
  };
}

exports.sendPushToUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const {uid, title, body, type} = request.data || {};
  // Allow self-send or admin-only expansion later.
  const targetUid = uid || request.auth.uid;
  if (targetUid !== request.auth.uid) {
    throw new HttpsError(
        "permission-denied",
        "Can only send to your own device tokens from the client.",
    );
  }
  try {
    return await sendToUser({uid: targetUid, title, body, type});
  } catch (e) {
    logger.error("sendPushToUser failed", e);
    throw new HttpsError("internal", e.message || "Send failed");
  }
});

// Optional HTTP endpoint for backend jobs (protect before production use).
exports.sendPushHttp = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("POST only");
    return;
  }
  try {
    const result = await sendToUser(req.body || {});
    res.json(result);
  } catch (e) {
    logger.error("sendPushHttp failed", e);
    res.status(400).json({error: e.message});
  }
});
