// =============================================================================
// Cloud Functions SideBySide - TUTTE di 1ª generazione (nessun uso di Eventarc)
// -----------------------------------------------------------------------------
// Con firebase-functions v6/v7 l'API di 1ª generazione si importa da
// "firebase-functions/v1": il semplice require("firebase-functions") ora
// restituisce l'API di 2ª generazione, dove functions.firestore.document
// non esiste più.
// =============================================================================
const functions = require("firebase-functions/v1");
const logger = functions.logger;
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Regione delle funzioni Firestore (la stessa del database)
const REGION = "europe-west1";

// ---------------------------------------------------------------------------
// getPlaces: proxy verso Google Places (usato dalla vecchia schermata Venus)
// ---------------------------------------------------------------------------
exports.getPlaces = functions
    .region(REGION)
    .https.onRequest(async (req, res) => {
      // Abilita i CORS per permettere l'accesso dal sito web
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      const {lat, lng} = req.query;
      // Google Places accetta un solo "type" per richiesta
      const type = (req.query.type || "restaurant").toString().split("|")[0];
      const apiKey = "AIzaSyBaO9OavQjO2E6YclqHusfFDlTK9VKJK2E";

      const googleUrl = "https://maps.googleapis.com/maps/api/place/nearbysearch/json" +
        `?location=${lat},${lng}&radius=2000&type=${encodeURIComponent(type)}&key=${apiKey}`;

      try {
        const response = await fetch(googleUrl);
        const data = await response.json();
        res.json(data);
      } catch (error) {
        res.status(500).send({error: error.message});
      }
    });

// ---------------------------------------------------------------------------
// Funzioni di supporto per le notifiche
// ---------------------------------------------------------------------------

/** Nome visualizzabile di un utente (firstName, poi name). */
async function getUserName(uid) {
  if (!uid) return "Un utente";
  const doc = await db.collection("users").doc(uid).get();
  if (!doc.exists) return "Un utente";
  const data = doc.data() || {};
  return (data.firstName && String(data.firstName).trim()) ||
    (data.name && String(data.name).trim()) ||
    "Un utente";
}

/**
 * Salva la notifica in 'notifications' (per la campanella) e invia la push
 * al dispositivo dell'utente, se ha un token FCM salvato.
 */
async function notifyUser(receiverId, title, body, data = {}) {
  if (!receiverId) return;

  // 1. Salva la notifica: così la campanella funziona anche se l'app era chiusa
  await db.collection("notifications").add({
    userId: receiverId,
    title: title,
    body: body,
    type: data.type || "generic",
    senderId: data.senderId || "",
    chatId: data.chatId || "",
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2. Invia la push se l'utente ha un token
  const receiverDoc = await db.collection("users").doc(receiverId).get();
  if (!receiverDoc.exists) return;
  const fcmToken = (receiverDoc.data() || {}).fcmToken;
  if (!fcmToken) return;

  // I valori in "data" devono essere tutti stringhe
  const stringData = {click_action: "FLUTTER_NOTIFICATION_CLICK"};
  for (const [key, value] of Object.entries(data)) {
    stringData[key] = String(value ?? "");
  }

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: {title, body},
      data: stringData,
      android: {
        priority: "high",
        notification: {channelId: "sidebyside_chat_channel"},
      },
    });
    logger.info(`Push inviata a ${receiverId}`);
  } catch (error) {
    logger.error("Errore durante l'invio della notifica push:", error);
    // Se il token non è più valido lo rimuoviamo, così non riproviamo inutilmente
    const code = error && error.code;
    if (code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token") {
      await db.collection("users").doc(receiverId)
          .update({fcmToken: admin.firestore.FieldValue.delete()})
          .catch(() => null);
    }
  }
}

// ---------------------------------------------------------------------------
// Notifica per Like e Super Like (collezione 'likes')
// ---------------------------------------------------------------------------
exports.sendPushNotificationOnLike = functions
    .region(REGION)
    .firestore.document("likes/{likeId}")
    .onCreate(async (snapshot, context) => {
      const like = snapshot.data() || {};

      // Supporta sia i campi nuovi (toUserId/fromUserId) sia quelli vecchi
      const receiverId = like.toUserId || like.receiverId;
      const senderId = like.fromUserId || like.senderId;
      const type = like.type || "like";
      if (!receiverId || !senderId || receiverId === senderId) return;

      const senderName = await getUserName(senderId);
      const isSuper = type === "super_like";

      const title = isSuper ? "💎 Nuovo Super Like!" : "❤️ Nuovo Cuoricino!";
      const body = isSuper ?
        `${senderName} ti ha mandato un Super Like!` :
        `${senderName} ha messo un like al tuo profilo!`;

      const ids = [senderId, receiverId].sort();
      await notifyUser(receiverId, title, body, {
        type: isSuper ? "super_like" : "like",
        senderId: senderId,
        chatId: ids.join("_"),
      });
    });

// ---------------------------------------------------------------------------
// Notifica per i nuovi messaggi in chat (chats/{chatId}/messages)
// ---------------------------------------------------------------------------
exports.sendPushNotificationOnMessage = functions
    .region(REGION)
    .firestore.document("chats/{chatId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
      const message = snapshot.data() || {};

      // I messaggi automatici creati da un like hanno già la loro notifica
      if (message.fromLike === true) return;

      const receiverId = message.receiverId;
      const senderId = message.senderId;
      if (!receiverId || !senderId || receiverId === senderId) return;

      const senderName = await getUserName(senderId);
      const text = String(message.text || "").trim();
      const title = message.isSuperLike ?
        `❤ Super Like da ${senderName}` :
        `💬 Nuovo messaggio da ${senderName}`;
      const body = text.length > 120 ? `${text.substring(0, 117)}...` : text;

      await notifyUser(receiverId, title, body || "Hai un nuovo messaggio", {
        type: "message",
        senderId: senderId,
        chatId: context.params.chatId,
      });
    });

// ---------------------------------------------------------------------------
// Azzeramento mensile della classifica: ogni 15 del mese alle 00:00 (Italia)
// 1. salva il podio (top 3) in 'leaderboard_winners/{AAAA-MM}' così lo
//    sviluppatore sa chi contattare per consegnare il premio
// 2. invia una notifica ai vincitori
// 3. azzera i punti di tutti gli utenti
// ---------------------------------------------------------------------------
exports.resetLeaderboardMonthly = functions
    .region(REGION)
    .pubsub.schedule("0 0 15 * *")
    .timeZone("Europe/Rome")
    .onRun(async () => {
      const now = new Date();
      const periodId = now.toLocaleDateString("sv-SE", {
        timeZone: "Europe/Rome",
      }).slice(0, 7); // es. "2026-12"

      // 1. Podio
      const topSnap = await db.collection("users")
          .orderBy("points", "desc")
          .limit(3)
          .get();

      const winners = [];
      topSnap.docs.forEach((doc, index) => {
        const u = doc.data() || {};
        if ((u.points || 0) <= 0) return;
        winners.push({
          rank: index + 1,
          uid: doc.id,
          name: u.firstName || u.name || "Utente",
          email: u.email || "",
          phoneNumber: u.phoneNumber || "",
          points: u.points || 0,
          prize: null, // da compilare: buono drink / ricarica / abbonamento
          contacted: false,
        });
      });

      await db.collection("leaderboard_winners").doc(periodId).set({
        period: periodId,
        closedAt: admin.firestore.FieldValue.serverTimestamp(),
        winners: winners,
      });
      logger.info(`Podio ${periodId} salvato`, {winners});

      // 2. Notifica ai vincitori
      for (const w of winners) {
        try {
          await notifyUser(
              w.uid,
              `🏆 Sei arrivato ${w.rank}° in classifica!`,
              "Complimenti! Lo sviluppatore ti contatterà a breve per " +
              "consegnarti il premio scelto.",
              {type: "leaderboard_win", rank: String(w.rank)},
          );
        } catch (e) {
          logger.warn(`Notifica vincitore ${w.uid} non inviata`, e);
        }
      }

      // 3. Azzeramento punti (a blocchi da 400 scritture)
      // Gli utenti azzerati escono dalla query, quindi si rilegge
      // semplicemente finché non resta nessuno con punti > 0.
      let resetCount = 0;
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const snap = await db.collection("users")
            .where("points", ">", 0)
            .limit(400)
            .get();
        if (snap.empty) break;

        const batch = db.batch();
        snap.docs.forEach((d) => batch.update(d.ref, {points: 0}));
        await batch.commit();
        resetCount += snap.size;
      }

      await db.collection("app_config").doc("leaderboard").set({
        lastResetAt: admin.firestore.FieldValue.serverTimestamp(),
        lastPeriod: periodId,
        resetUsers: resetCount,
      }, {merge: true});

      logger.info(`Classifica azzerata: ${resetCount} utenti`);
      return null;
    });
