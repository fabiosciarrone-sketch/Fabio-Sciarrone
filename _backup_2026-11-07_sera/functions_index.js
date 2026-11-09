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

      // Punti al mittente: +10 per un Super Like, +5 per un messaggio
      await awardPoints(
          senderId,
          message.isSuperLike ? "superlike" : "message",
          `msg_${context.params.chatId}_${context.params.messageId}`,
      );
    });

// =============================================================================
// PUNTI DELLA CLASSIFICA - assegnati SOLO dal server
// -----------------------------------------------------------------------------
// L'app non può più scrivere il campo 'points' (lo vietano le regole
// Firestore). Ogni azione che dà punti viene registrata qui:
// - 'points_ledger/{chiave}' evita di dare due volte i punti per la stessa
//   azione (es. togliere e rimettere un Mi Piace)
// - 'points_daily/{uid}_{giorno}' applica un tetto giornaliero per tipo di
//   azione, così lo spam di messaggi non fa vincere la classifica
// Entrambe le collezioni hanno il campo 'expireAt': se attivi la policy TTL
// su quel campo in console, Firestore le ripulisce da solo.
// =============================================================================

/** Punti per azione e quante volte al giorno valgono. */
const POINT_RULES = {
  message: {points: 5, dailyMax: 20}, // max 100 pt/giorno
  superlike: {points: 10, dailyMax: 5}, // max 50 pt/giorno
  review: {points: 15, dailyMax: 3}, // max 45 pt/giorno
  review_like: {points: 5, dailyMax: 10}, // max 50 pt/giorno
  place: {points: 15, dailyMax: 2}, // max 30 pt/giorno
  profile: {points: 0, dailyMax: 1000}, // importo variabile, vedi sotto
};

const LEDGER_DAYS = 40;

/** Giorno corrente in Italia, es. "2026-11-07". */
function todayRome() {
  return new Date().toLocaleDateString("sv-SE", {timeZone: "Europe/Rome"});
}

/**
 * Assegna i punti di un'azione a un utente, una sola volta per [eventKey]
 * e nel rispetto del tetto giornaliero. [amount] serve solo per 'profile'.
 * [extraUserFields] viene scritto sull'utente nella stessa transazione.
 * Restituisce i punti effettivamente dati (0 se nulla).
 */
async function awardPoints(uid, reason, eventKey, amount, extraUserFields) {
  const rule = POINT_RULES[reason];
  if (!uid || !rule) return 0;
  const pts = amount != null ? amount : rule.points;
  if (pts <= 0) return 0;

  const userRef = db.collection("users").doc(uid);
  const ledgerRef = db.collection("points_ledger")
      .doc(eventKey.replace(/\//g, "_"));
  const day = todayRome();
  const dailyRef = db.collection("points_daily").doc(`${uid}_${day}`);
  const expireAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + LEDGER_DAYS * 24 * 60 * 60 * 1000);

  try {
    return await db.runTransaction(async (tx) => {
      const [userSnap, ledgerSnap, dailySnap] = await Promise.all([
        tx.get(userRef), tx.get(ledgerRef), tx.get(dailyRef),
      ]);
      if (!userSnap.exists || ledgerSnap.exists) return 0;
      if ((userSnap.data() || {}).isDummy === true) return 0;

      const counts = dailySnap.exists ? (dailySnap.data().counts || {}) : {};
      const done = counts[reason] || 0;
      if (done >= rule.dailyMax) return 0;

      tx.set(ledgerRef, {
        uid, reason, points: pts, expireAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.set(dailyRef, {
        uid, day, expireAt,
        counts: {[reason]: done + 1},
      }, {merge: true});
      tx.update(userRef, {
        ...(extraUserFields || {}),
        points: admin.firestore.FieldValue.increment(pts),
      });
      return pts;
    });
  } catch (e) {
    logger.error(`Punti non assegnati (${reason}) a ${uid}`, e);
    return 0;
  }
}

// ---------------------------------------------------------------------------
// +15 per una nuova recensione
// ---------------------------------------------------------------------------
exports.awardPointsOnReview = functions
    .region(REGION)
    .firestore.document("reviews/{reviewId}")
    .onCreate(async (snapshot, context) => {
      const review = snapshot.data() || {};
      await awardPoints(review.userId, "review",
          `review_${context.params.reviewId}`);
    });

// ---------------------------------------------------------------------------
// +5 a chi mette Mi Piace a una recensione (una volta sola per recensione,
// mai sulla propria)
// ---------------------------------------------------------------------------
exports.awardPointsOnReviewLike = functions
    .region(REGION)
    .firestore.document("reviews/{reviewId}")
    .onUpdate(async (change, context) => {
      const before = new Set((change.before.data() || {}).likedBy || []);
      const after = (change.after.data() || {}).likedBy || [];
      const author = (change.after.data() || {}).userId;
      for (const uid of after) {
        if (before.has(uid) || uid === author) continue;
        await awardPoints(uid, "review_like",
            `reviewlike_${context.params.reviewId}_${uid}`);
      }
    });

// ---------------------------------------------------------------------------
// +15 per una nuova stanza/locale nella Community
// ---------------------------------------------------------------------------
exports.awardPointsOnPlace = functions
    .region(REGION)
    .firestore.document("places/{placeId}")
    .onCreate(async (snapshot, context) => {
      const place = snapshot.data() || {};
      await awardPoints(place.createdBy, "place",
          `place_${context.params.placeId}`);
    });

// ---------------------------------------------------------------------------
// Punti del profilo: +50 profilo completo, +20 per ogni foto (max 5).
// Si danno solo una volta: 'profilePointsAwarded' ricorda quanti ne ha già
// presi l'utente, così salvare il profilo più volte non dà altri punti.
// ---------------------------------------------------------------------------
const PROFILE_MAX_PHOTOS = 5;

exports.awardProfilePoints = functions
    .region(REGION)
    .firestore.document("users/{uid}")
    .onWrite(async (change, context) => {
      if (!change.after.exists) return;
      const u = change.after.data() || {};
      if (u.isDummy === true) return;

      const complete =
        String(u.firstName || "").trim() !== "" &&
        String(u.bio || "").trim() !== "" &&
        Number(u.age || 0) > 0;
      const photos = Math.min(
          Array.isArray(u.galleryPhotos) ? u.galleryPhotos.length : 0,
          PROFILE_MAX_PHOTOS);
      const target = (complete ? 50 : 0) + photos * 20;
      const already = Number(u.profilePointsAwarded || 0);
      if (target <= already) return; // niente da dare: evita anche i loop

      const uid = context.params.uid;
      const delta = target - already;
      await awardPoints(uid, "profile", `profile_${uid}_${target}`, delta,
          {profilePointsAwarded: target});
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
