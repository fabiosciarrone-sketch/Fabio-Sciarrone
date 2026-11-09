import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import 'chat_utils.dart';
import 'photo_utils.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  Stream<QuerySnapshot>? _participantsStream;
  Stream<QuerySnapshot>? _usersStream;

  @override
  void initState() {
    super.initState();
    if (currentUserId != null) {
      final chats = FirebaseFirestore.instance.collection('chats');
      _participantsStream =
          chats.where('participants', arrayContains: currentUserId).snapshots();
      _usersStream =
          chats.where('users', arrayContains: currentUserId).snapshots();
    }
  }

  /// Data dell'ultimo messaggio (supporta anche il vecchio campo
  /// 'lastMessageTimestamp' usato dalla griglia utenti).
  static DateTime _lastActivity(Map<String, dynamic> data) {
    final ts = data['lastTimestamp'] ?? data['lastMessageTimestamp'];
    if (ts is Timestamp) return ts.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Utente non autenticato')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Le tue Chat',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
        centerTitle: true,
      ),
      // Ascoltiamo sia il campo nuovo 'participants' sia il vecchio 'users',
      // così compaiono anche le chat create prima di questa correzione.
      body: StreamBuilder<QuerySnapshot>(
        stream: _participantsStream,
        builder: (context, participantsSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: _usersStream,
            builder: (context, usersSnap) {
              final bothWaiting =
                  participantsSnap.connectionState == ConnectionState.waiting &&
                      usersSnap.connectionState == ConnectionState.waiting;
              if (bothWaiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Unisce i risultati delle due query eliminando i doppioni
              final Map<String, QueryDocumentSnapshot> merged = {};
              for (final doc in participantsSnap.data?.docs ?? []) {
                merged[doc.id] = doc;
              }
              for (final doc in usersSnap.data?.docs ?? []) {
                merged[doc.id] = doc;
              }

              final docs = merged.values.toList()
                ..sort((a, b) {
                  final da = _lastActivity(a.data() as Map<String, dynamic>);
                  final db = _lastActivity(b.data() as Map<String, dynamic>);
                  return db.compareTo(da); // più recenti in alto
                });

              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Nessuna chat attiva',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vai nella sezione "Intorno" per chattare con qualcuno!',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return _ChatTile(
                    key: ValueKey(doc.id),
                    chatId: doc.id,
                    chatData: doc.data() as Map<String, dynamic>,
                    currentUserId: currentUserId,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Riga della lista chat: mostra nome e foto dell'altra persona.
/// Se il nome non è salvato nella chat, lo legge dal profilo utente.
class _ChatTile extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> chatData;
  final String currentUserId;

  const _ChatTile({
    super.key,
    required this.chatId,
    required this.chatData,
    required this.currentUserId,
  });

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  late final String _otherId;
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _otherUserFuture;

  @override
  void initState() {
    super.initState();
    _otherId = _findOtherId();
    _otherUserFuture =
        FirebaseFirestore.instance.collection('users').doc(_otherId).get();
  }

  String _findOtherId() {
    final list = widget.chatData['participants'] ?? widget.chatData['users'];
    if (list is List) {
      for (final id in list) {
        if (id is String && id != widget.currentUserId && id.isNotEmpty) {
          return id;
        }
      }
    }
    return ChatUtils.otherUserId(widget.chatId, widget.currentUserId);
  }

  String? _savedName() {
    final names = widget.chatData['participantNames'];
    if (names is Map) {
      final value = names[_otherId];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    final legacy = widget.chatData['receiverName'];
    if (legacy is String && legacy.trim().isNotEmpty) return legacy.trim();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final lastMessage =
        (widget.chatData['lastMessage'] ?? 'Inizia una conversazione...')
            .toString();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _otherUserFuture,
      builder: (context, snapshot) {
        final userData = snapshot.data?.data();
        // Priorità: nome attuale dal profilo, poi nome salvato nella chat
        final fromProfile =
            userData != null ? ChatUtils.nameFromUserData(userData) : null;
        final name = (fromProfile != null && fromProfile != 'Utente')
            ? fromProfile
            : (_savedName() ?? 'Utente');
        final photo =
            (userData?['profilePhotoUrl'] ?? userData?['photo'] ?? '')
                .toString();
        final photoProvider = PhotoUtils.provider(photo);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.purple,
            backgroundImage: photoProvider,
            child: photoProvider == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          title:
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(lastMessage,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: widget.chatId,
                  receiverName: name,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
