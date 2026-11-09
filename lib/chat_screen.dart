import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'premium_screen.dart';
import 'chat_utils.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  String? _myName; // Nome dell'utente corrente, salvato nella chat

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    _loadMyName();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMyName() async {
    if (currentUser == null) return;
    final name = await ChatUtils.fetchUserName(currentUser!.uid);
    if (mounted) _myName = name;
  }

  /// Aggiorna il documento della chat con partecipanti, nomi e ultimo messaggio
  /// così la conversazione compare sempre nella lista "Le tue Chat".
  Future<void> _updateChatDocument(String lastMessage) async {
    if (currentUser == null) return;
    _myName ??= await ChatUtils.fetchUserName(currentUser!.uid);
    await ChatUtils.upsertChat(
      chatId: widget.chatId,
      myId: currentUser!.uid,
      otherId: _getReceiverId(),
      myName: _myName,
      otherName: widget.receiverName,
      lastMessage: lastMessage,
    );
  }

  void _markMessagesAsRead() async {
    if (currentUser == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser!.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.update({'isRead': true});
      }
    } on FirebaseException catch (e) {
      // Permessi negati o altro errore Firestore: la chat resta utilizzabile
      if (e.code == 'permission-denied') {
        debugPrint('Messaggi non segnati come letti: permessi Firestore '
            'insufficienti sui messaggi della chat ${widget.chatId}.');
      } else {
        debugPrint('Errore aggiornamento messaggi letti: $e');
      }
    } catch (e) {
      debugPrint('Errore aggiornamento messaggi letti: $e');
    }
  }

  String _getReceiverId() {
    if (currentUser == null) return '';
    return ChatUtils.otherUserId(widget.chatId, currentUser!.uid);
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || currentUser == null) return;

    String receiverId = _getReceiverId();

    try {
      QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();

      bool receiverHasReplied = false;
      int myConsecutiveMessages = 0;

      for (var doc in messagesSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String senderId = data['senderId'] ?? '';
        if (senderId == receiverId) {
          receiverHasReplied = true;
          break;
        } else if (senderId == currentUser!.uid) {
          myConsecutiveMessages++;
        }
      }

      if (!receiverHasReplied && myConsecutiveMessages >= 2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Hai esaurito i 2 messaggi gratuiti! Passa a Premium per continuare a scrivere 🔒'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PremiumScreen()),
        );
        return;
      }
    } catch (e) {
      debugPrint("Errore controllo messaggi chat: $e");
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': currentUser!.uid,
      'text': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'isSuperLike': false,
      'receiverId': receiverId,
      'isRead': false,
    });

    await _updateChatDocument(messageText);

    // I punti (+5) li assegna la Cloud Function 'sendPushNotificationOnMessage':
    // l'app non può più modificare i punti direttamente.

    // La notifica push al destinatario la invia la Cloud Function
    // 'sendPushNotificationOnMessage' quando il messaggio viene salvato.
  }

  void _sendSuperLike() async {
    if (currentUser == null) return;
    String receiverId = _getReceiverId();

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);

    bool success = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists || !snapshot.data()!.containsKey('hearts')) {
        return false;
      }
      int currentHearts = snapshot.data()!['hearts'];
      if (currentHearts <= 0) {
        return false;
      }

      transaction.update(userRef, {'hearts': currentHearts - 1});
      return true;
    });

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Non hai abbastanza cuoricini! Guarda un video nel tuo profilo per ricaricarli.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': currentUser!.uid,
      'receiverId': receiverId, // <-- AGGIUNTO QUI
      'text': '❤ Ha inviato un Super Like!',
      'timestamp': FieldValue.serverTimestamp(),
      'isSuperLike': true,
      'isRead': false,
    });

    await _updateChatDocument('❤ Ha inviato un Super Like!');

    // I punti (+10) li assegna la Cloud Function sul messaggio.


    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Super Like inviato con successo! ❤ (+10 pt)'),
        backgroundColor: Colors.pink,
      ),
    );
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Blocca utente'),
        content: const Text(
            'Non vedrai più questo utente e non potrà più contattarti.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              if (currentUser == null) return;
              String receiverId = _getReceiverId();

              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .set({
                  'blockedUsers': FieldValue.arrayUnion([receiverId])
                }, SetOptions(merge: true));

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Utente bloccato con successo.')),
                );
              } catch (e) {
                debugPrint("Errore blocco utente: $e");
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Errore durante il blocco: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Blocca', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _reportUser() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Segnala utente'),
        content: const Text(
            'Vuoi segnalare questo profilo per comportamento inappropriato?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              if (currentUser == null) return;
              String receiverId = _getReceiverId();

              try {
                await FirebaseFirestore.instance.collection('reports').add({
                  'reporterId': currentUser!.uid,
                  'reportedUserId': receiverId,
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'pending',
                });

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Segnalazione inviata agli amministratori. Grazie.'),
                  ),
                );
              } catch (e) {
                debugPrint("Errore segnalazione utente: $e");
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Errore durante la segnalazione: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child:
                const Text('Segnala', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverName),
        backgroundColor: Colors.purple,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') _blockUser();
              if (value == 'report') _reportUser();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text('Segnala utente'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Blocca utente'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markMessagesAsRead();
                  });
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nessun messaggio. Inizia la conversazione o manda un Super Like',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == currentUser?.uid;
                    final isSuperLike = message['isSuperLike'] ?? false;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSuperLike
                              ? Colors.pink.shade100
                              : (isMe
                                  ? Colors.purple.shade100
                                  : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                          border: isSuperLike
                              ? Border.all(color: Colors.pink, width: 1.5)
                              : null,
                        ),
                        child: Text(
                          message['text'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSuperLike
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSuperLike
                                ? Colors.pink.shade900
                                : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.pink),
                  onPressed: _sendSuperLike,
                  tooltip: 'Invia Super Like (-1 Cuore)',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Scrivi un messaggio...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.purple),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
