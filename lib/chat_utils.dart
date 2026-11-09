import 'package:cloud_firestore/cloud_firestore.dart';

/// Funzioni condivise per creare e aggiornare le chat in modo coerente.
///
/// Ogni documento in `chats/{chatId}` usa questi campi:
/// - participants: [uidA, uidB]          -> usato dalla lista chat
/// - users: [uidA, uidB]                 -> vecchio nome del campo (compatibilità)
/// - participantNames: {uidA: nome, uidB: nome}
/// - lastMessage, lastTimestamp
class ChatUtils {
  ChatUtils._();

  /// ID della chat tra due utenti (sempre lo stesso, in qualunque ordine).
  static String chatIdFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  /// Ricava l'ID dell'altro partecipante dal chatId.
  static String otherUserId(String chatId, String myId) {
    final ids = chatId.split('_');
    for (final id in ids) {
      if (id != myId && id.isNotEmpty) return id;
    }
    return ids.isNotEmpty ? ids.last : chatId;
  }

  /// Nome visualizzabile di un utente a partire dai dati del documento.
  static String nameFromUserData(Map<String, dynamic>? data) {
    if (data == null) return 'Utente';
    for (final key in ['firstName', 'name']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return 'Utente';
  }

  /// Legge il nome di un utente da Firestore.
  static Future<String> fetchUserName(String uid) async {
    if (uid.isEmpty) return 'Utente';
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return nameFromUserData(doc.data());
    } catch (_) {
      return 'Utente';
    }
  }

  /// Crea o aggiorna il documento della chat con partecipanti, nomi e
  /// ultimo messaggio. Usa merge, quindi non cancella altri campi.
  static Future<void> upsertChat({
    required String chatId,
    required String myId,
    required String otherId,
    String? myName,
    String? otherName,
    String? lastMessage,
  }) async {
    final participants = [myId, otherId]..sort();
    final names = <String, String>{};
    if (myName != null && myName.trim().isNotEmpty) {
      names[myId] = myName.trim();
    }
    if (otherName != null && otherName.trim().isNotEmpty) {
      names[otherId] = otherName.trim();
    }

    final data = <String, dynamic>{
      'participants': participants,
      'users': participants,
      if (names.isNotEmpty) 'participantNames': names,
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessage != null) 'lastTimestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .set(data, SetOptions(merge: true));
  }
}
