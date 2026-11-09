import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Logica della Community: stanze (places), iscritti e chat delle stanze.
///
/// Struttura su Firestore:
/// - places/{placeId}                     la stanza
/// - places/{placeId}/members/{uid}       chi si è unito
/// - places/{placeId}/messages/{msgId}    i messaggi della chat
/// - reports/pm_{placeId}_{msgId}_{uid}   segnalazione di un messaggio
///
/// Il contatore 'membersCount', i punti e l'oscuramento dei messaggi
/// segnalati li gestiscono le Cloud Functions: l'app non può modificarli.
class CommunityService {
  CommunityService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int maxNameLength = 60;
  static const int maxDescriptionLength = 300;
  static const int maxMessageLength = 1000;

  /// Limite per le foto nei messaggi (testo base64): circa 300 KB.
  static const int maxImageBase64Length = 400000;

  static String? get myUid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get places =>
      _db.collection('places');

  static DocumentReference<Map<String, dynamic>> memberRef(
          String placeId, String uid) =>
      places.doc(placeId).collection('members').doc(uid);

  static CollectionReference<Map<String, dynamic>> messages(String placeId) =>
      places.doc(placeId).collection('messages');

  // ---------------------------------------------------------------------
  // Conversioni sicure (Firestore può restituire int, double o null)
  // ---------------------------------------------------------------------
  static double? asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int asInt(dynamic v, [int fallback = 0]) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  // ---------------------------------------------------------------------
  // Nome da mostrare nei messaggi
  // ---------------------------------------------------------------------
  static Future<String> myDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Utente';
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      final first = (data['firstName'] ?? '').toString().trim();
      if (first.isNotEmpty) return first;
      final name = (data['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    } catch (_) {}
    final display = (user.displayName ?? '').trim();
    return display.isNotEmpty ? display : 'Utente';
  }

  /// UID che l'utente ha bloccato (campo 'blockedUsers' del suo profilo).
  static Future<Set<String>> myBlockedUsers() async {
    final uid = myUid;
    if (uid == null) return {};
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final list = (doc.data() ?? {})['blockedUsers'];
      if (list is List) return list.map((e) => e.toString()).toSet();
    } catch (_) {}
    return {};
  }

  // ---------------------------------------------------------------------
  // Stanze
  // ---------------------------------------------------------------------

  /// Crea la stanza e iscrive subito chi l'ha creata.
  /// Restituisce l'ID della nuova stanza.
  static Future<String> createPlace({
    required String name,
    required String description,
    required String category,
    double? latitude,
    double? longitude,
  }) async {
    final uid = myUid;
    if (uid == null) throw StateError('Utente non autenticato');

    final ref = await places.add({
      'name': name.trim(),
      'category': category,
      'description': description.trim().isNotEmpty
          ? description.trim()
          : 'Nuovo punto di ritrovo creato dalla community.',
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      // Lo incrementa la Cloud Function quando qualcuno si unisce
      'membersCount': 0,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await join(ref.id);
    return ref.id;
  }

  // ---------------------------------------------------------------------
  // Iscrizione
  // ---------------------------------------------------------------------
  static Stream<bool> isMemberStream(String placeId) {
    final uid = myUid;
    if (uid == null) return Stream.value(false);
    return memberRef(placeId, uid).snapshots().map((s) => s.exists);
  }

  static Future<void> join(String placeId) async {
    final uid = myUid;
    if (uid == null) return;
    final ref = memberRef(placeId, uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'name': await myDisplayName(),
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> leave(String placeId) async {
    final uid = myUid;
    if (uid == null) return;
    await memberRef(placeId, uid).delete();
  }

  // ---------------------------------------------------------------------
  // Messaggi
  // ---------------------------------------------------------------------
  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(
      String placeId) {
    return messages(placeId)
        .orderBy('timestamp', descending: true)
        .limit(150)
        .snapshots();
  }

  /// Invia un messaggio di testo e/o una foto. Solo per chi è iscritto
  /// (lo controllano le regole Firestore).
  static Future<void> sendMessage({
    required String placeId,
    required String senderName,
    String text = '',
    Uint8List? imageBytes,
  }) async {
    final uid = myUid;
    if (uid == null) return;

    final cleanText = text.trim();
    String? imageBase64;
    if (imageBytes != null) {
      imageBase64 = base64Encode(imageBytes);
      if (imageBase64.length > maxImageBase64Length) {
        throw const CommunityException(
            'La foto è troppo grande. Scegline una più piccola.');
      }
    }
    if (cleanText.isEmpty && imageBase64 == null) return;
    if (cleanText.length > maxMessageLength) {
      throw const CommunityException('Il messaggio è troppo lungo.');
    }

    await messages(placeId).add({
      'senderId': uid,
      'senderName': senderName,
      'text': cleanText,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      'timestamp': FieldValue.serverTimestamp(),
      'hidden': false,
      'reportCount': 0,
    });
  }

  static Future<void> deleteMyMessage(String placeId, String messageId) =>
      messages(placeId).doc(messageId).delete();

  // ---------------------------------------------------------------------
  // Segnalazioni
  // ---------------------------------------------------------------------

  /// Segnala un messaggio. Ogni utente può segnalare lo stesso messaggio
  /// una sola volta: l'ID della segnalazione è fisso e le regole vietano
  /// di sovrascriverla.
  static Future<ReportOutcome> reportMessage({
    required String placeId,
    required String messageId,
    required Map<String, dynamic> message,
    required String reason,
  }) async {
    final uid = myUid;
    if (uid == null) return ReportOutcome.error;
    final text = (message['text'] ?? '').toString();
    try {
      await _db.collection('reports').doc('pm_${placeId}_${messageId}_$uid').set({
        'type': 'place_message',
        'reporterId': uid,
        'reportedUserId': (message['senderId'] ?? '').toString(),
        'placeId': placeId,
        'messageId': messageId,
        'reason': reason,
        'textSnapshot':
            text.length > 300 ? '${text.substring(0, 300)}...' : text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      return ReportOutcome.sent;
    } on FirebaseException catch (e) {
      // La segnalazione esiste già: set() diventa un aggiornamento, vietato
      if (e.code == 'permission-denied') return ReportOutcome.alreadyReported;
      return ReportOutcome.error;
    } catch (_) {
      return ReportOutcome.error;
    }
  }
}

enum ReportOutcome { sent, alreadyReported, error }

class CommunityException implements Exception {
  final String message;
  const CommunityException(this.message);
  @override
  String toString() => message;
}
