import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'premium_screen.dart';
import 'user_profile_screen.dart'; // Importato per aprire il profilo utente
import 'chat_utils.dart';
import 'photo_utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class UserGridWidget extends StatefulWidget {
  const UserGridWidget({super.key});

  @override
  State<UserGridWidget> createState() => _UserGridWidgetState();
}

class _UserGridWidgetState extends State<UserGridWidget> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _saveFCMToken(); // Salva il token all'avvio della griglia
  }

  Future<void> _saveFCMToken() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();

        if (token != null && currentUserId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .set({
            'fcmToken': token,
          }, SetOptions(merge: true));

          debugPrint("Token FCM salvato con successo: $token");
        }
      }
    } catch (e) {
      debugPrint("Errore nel salvataggio del token FCM: $e");
    }
  }

  // Da qui in poi rimane tutto il tuo codice esistente (_sendLike, ecc.)
  Future<void> _sendLike(
      String receiverId, String receiverName, String receiverPhotoUrl) async {
    if (currentUserId.isEmpty) return;

    try {
      // Controlla i cuori al momento del click senza ricaricare la schermata
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      int userHearts = userDoc.data()?['hearts'] ?? 0;

      if (userHearts <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Non hai abbastanza cuori! Ricarica nella sezione Premium ❤️'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PremiumScreen()),
        );
        return;
      }

      // 1. Scala il cuore all'utente corrente
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set({
        'hearts': FieldValue.increment(-1),
      }, SetOptions(merge: true));

      // 2. Salva il like nella collezione 'likes' su Firestore
      await FirebaseFirestore.instance.collection('likes').add({
        'fromUserId': currentUserId,
        'toUserId': receiverId,
        'type': 'like',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Controllo del match reciproco su Firestore
      final matchQuery = await FirebaseFirestore.instance
          .collection('likes')
          .where('fromUserId', isEqualTo: receiverId)
          .where('toUserId', isEqualTo: currentUserId)
          .get();

      bool isMatch = matchQuery.docs.isNotEmpty;
      String chatMessage = isMatch
          ? '🎉 È un Match! Vi siete piaciuti a vicenda ❤️'
          : 'Ti ha mandato un cuoricino ❤️';

      // 4. Crea o aggiorna la chat e invia il messaggio visibile
      String chatId = ChatUtils.chatIdFor(currentUserId, receiverId);

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'receiverId': receiverId,
        'text': chatMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        // Messaggio automatico del like: la notifica la manda già la
        // Cloud Function dei like, così non arriva doppia.
        'fromLike': true,
      });

      await ChatUtils.upsertChat(
        chatId: chatId,
        myId: currentUserId,
        otherId: receiverId,
        myName: ChatUtils.nameFromUserData(userDoc.data()),
        otherName: receiverName,
        lastMessage: chatMessage,
      );

      if (!mounted) return;

      if (isMatch) {
        String currentPhotoUrl = userDoc.data()?['profilePhotoUrl'] ??
            userDoc.data()?['photo'] ??
            '';
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => MatchPopupWidget(
            currentUserId: currentUserId,
            receiverId: receiverId,
            receiverName: receiverName,
            currentPhotoUrl: currentPhotoUrl,
            receiverPhotoUrl: receiverPhotoUrl,
            isSuperLike: false, // Match normale con cuoricino
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Hai mandato un cuoricino a $receiverName ❤️ (-1 Cuore)'),
            backgroundColor: Colors.pink,
          ),
        );
      }
    } catch (e) {
      debugPrint("Errore invio like: $e");
    }
  }

  Future<void> _sendSuperLike(
      String receiverId, String receiverName, String receiverPhotoUrl) async {
    if (currentUserId.isEmpty) return;

    try {
      // Controlla i diamanti al momento del click senza ricaricare la schermata
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      int userDiamonds = userDoc.data()?['diamonds'] ?? 0;

      if (userDiamonds <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Non hai abbastanza diamanti per il Super Like! Ricarica o guarda un video 💎'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PremiumScreen()),
        );
        return;
      }

      // 1. Scala il diamante all'utente corrente
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set({
        'diamonds': FieldValue.increment(-1),
      }, SetOptions(merge: true));

      // 2. Salva il Super Like nella collezione 'likes' su Firestore
      await FirebaseFirestore.instance.collection('likes').add({
        'fromUserId': currentUserId,
        'toUserId': receiverId,
        'type': 'super_like',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Controllo del match reciproco su Firestore
      final matchQuery = await FirebaseFirestore.instance
          .collection('likes')
          .where('fromUserId', isEqualTo: receiverId)
          .where('toUserId', isEqualTo: currentUserId)
          .get();

      bool isMatch = matchQuery.docs.isNotEmpty;
      String chatMessage = isMatch
          ? '💎🎉 È un Match con Super Like!'
          : 'Ti ha mandato un Super Like 💎!';

      // 4. Crea o aggiorna la chat e invia il messaggio visibile
      String chatId = ChatUtils.chatIdFor(currentUserId, receiverId);

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'receiverId': receiverId,
        'text': chatMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        // Messaggio automatico del like: la notifica la manda già la
        // Cloud Function dei like, così non arriva doppia.
        'fromLike': true,
      });

      await ChatUtils.upsertChat(
        chatId: chatId,
        myId: currentUserId,
        otherId: receiverId,
        myName: ChatUtils.nameFromUserData(userDoc.data()),
        otherName: receiverName,
        lastMessage: chatMessage,
      );

      if (!mounted) return;

      if (isMatch) {
        String currentPhotoUrl = userDoc.data()?['profilePhotoUrl'] ??
            userDoc.data()?['photo'] ??
            '';
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => MatchPopupWidget(
            currentUserId: currentUserId,
            receiverId: receiverId,
            receiverName: receiverName,
            currentPhotoUrl: currentPhotoUrl,
            receiverPhotoUrl: receiverPhotoUrl,
            isSuperLike: true, // Super Match con Diamante!
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Hai mandato un Super Like 💎 a $receiverName! (-1 Diamante)'),
            backgroundColor: Colors.cyan,
          ),
        );
      }
    } catch (e) {
      debugPrint("Errore invio super like: $e");
    }
  }

  void _openChat(String receiverId, String receiverName) {
    String chatId = ChatUtils.chatIdFor(currentUserId, receiverId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          receiverName: receiverName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFC4B5FD)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text('Nessun utente trovato',
                  style: TextStyle(color: Colors.white70)));
        }

        // Esclude l'utente corrente dalla griglia
        final users = snapshot.data!.docs
            .where((doc) => doc.id != currentUserId)
            .toList();

        if (users.isEmpty) {
          return const Center(
              child: Text('Nessun altro utente trovato',
                  style: TextStyle(color: Colors.white70)));
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // Due colonne per una griglia ordinata
            childAspectRatio: 0.75, // Rapporto verticale (stile social)
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: users.length,
          itemBuilder: (context, index) {
            var userData = users[index].data() as Map<String, dynamic>;
            var userId = users[index].id;

            String name = userData['firstName'] ?? userData['name'] ?? 'Utente';
            int age = userData['age'] ?? 0;
            String photoUrl =
                userData['profilePhotoUrl'] ?? userData['photo'] ?? '';

            // GestureDetector aggiunto per aprire il profilo al click sulla card
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(userId: userId),
                  ),
                );
              },
              child: Card(
                elevation: 8,
                color: const Color(0xFF1B1035),
                shadowColor: const Color(0xFF8B5CF6).withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: Colors.white.withOpacity(0.14), width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // 1. Foto Profilo a tutto schermo (Immersiva e sicura)
                    Positioned.fill(
                      child: PhotoUtils.image(photoUrl),
                    ),

                    // 2. Sfumatura in basso per leggere bene il nome e l'età
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFF0E0820).withOpacity(0.9),
                            ],
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // 3. Nome, Età, Chat, Diamante e Cuoricino in basso
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$name, $age',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              // Pulsante Chat
                              GestureDetector(
                                onTap: () => _openChat(userId, name),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.25)),
                                  ),
                                  child: const Icon(Icons.chat_bubble_outline,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Diamante (Super Like) interattivo
                              GestureDetector(
                                onTap: () =>
                                    _sendSuperLike(userId, name, photoUrl),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.25)),
                                  ),
                                  child: const Icon(Icons.diamond,
                                      color: Colors.cyanAccent, size: 20),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Cuoricino interattivo
                              GestureDetector(
                                onTap: () => _sendLike(userId, name, photoUrl),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.25)),
                                  ),
                                  child: const Icon(Icons.favorite,
                                      color: Colors.redAccent, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// WIDGET ANIMATO PER LA GRAFICA DEL MATCH
// ==========================================
class MatchPopupWidget extends StatefulWidget {
  final String currentUserId;
  final String receiverId;
  final String receiverName;
  final String currentPhotoUrl;
  final String receiverPhotoUrl;
  final bool isSuperLike;

  const MatchPopupWidget({
    super.key,
    required this.currentUserId,
    required this.receiverId,
    required this.receiverName,
    required this.currentPhotoUrl,
    required this.receiverPhotoUrl,
    this.isSuperLike = false,
  });

  @override
  State<MatchPopupWidget> createState() => _MatchPopupWidgetState();
}

class _MatchPopupWidgetState extends State<MatchPopupWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation1;
  late Animation<double> _slideAnimation2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _slideAnimation1 = Tween<double>(begin: -180.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _slideAnimation2 = Tween<double>(begin: 180.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAvatar(String photoUrl) {
    return PhotoUtils.image(
      photoUrl,
      placeholder: Container(
        color: Colors.grey[800],
        child: const Icon(Icons.person, color: Colors.white54, size: 50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Distinzione grafica dinamica tra Super Match (diamante) e Match standard
    final Color primaryColor =
        widget.isSuperLike ? Colors.cyanAccent : Colors.pinkAccent;
    final String titleText =
        widget.isSuperLike ? 'SUPER MATCH! 💎' : 'IT\'S A MATCH!';
    final Color shadowColor = widget.isSuperLike
        ? Colors.cyan.withOpacity(0.6)
        : Colors.pink.withOpacity(0.6);

    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.92),
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              titleText,
              style: TextStyle(
                color: primaryColor,
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isSuperLike
                  ? 'Hai fatto un Super Match con ${widget.receiverName} 💎!'
                  : 'Tu e ${widget.receiverName} vi siete piaciuti!',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            // Animazione foto che si incrociano al centro
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return SizedBox(
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Foto utente corrente (scivola da sinistra)
                      Transform.translate(
                        offset: Offset(_slideAnimation1.value, 0),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: ClipOval(
                            child: _buildAvatar(widget.currentPhotoUrl),
                          ),
                        ),
                      ),
                      // Foto utente ricevente (scivola da destra)
                      Transform.translate(
                        offset: Offset(_slideAnimation2.value, 0),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: ClipOval(
                            child: _buildAvatar(widget.receiverPhotoUrl),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 60),
            // Pulsante per aprire direttamente la chat del match
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor:
                    widget.isSuperLike ? Colors.black : Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
              onPressed: () {
                // Prendiamo il Navigator PRIMA di chiudere il popup:
                // dopo la chiusura il context del popup non è più valido.
                final navigator = Navigator.of(context);
                navigator.pop(); // Chiudi il popup del match
                String chatId = ChatUtils.chatIdFor(
                    widget.currentUserId, widget.receiverId);
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatId: chatId,
                      receiverName: widget.receiverName,
                    ),
                  ),
                );
              },
              child: const Text(
                'Manda un messaggio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Continua a guardare',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
