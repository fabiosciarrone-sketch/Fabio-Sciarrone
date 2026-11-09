import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'photo_utils.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classifica & Premi 🏆'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          // Sezione Banner Premi Mensili
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade700, Colors.pink.shade500],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎁 Premi Mensili Top 3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'I primi 3 classificati vincono un premio a scelta tra:',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const _PrizeLine(icon: '🍹', text: 'un buono drink'),
                const _PrizeLine(icon: '📱', text: 'una ricarica telefonica'),
                const _PrizeLine(
                    icon: '⭐', text: "un mese di abbonamento gratuito all'app"),
                const SizedBox(height: 10),
                const Text(
                  "📩 I vincitori del podio verranno contattati direttamente dallo sviluppatore per ricevere il premio scelto.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🔄 La classifica si azzera ogni 15 del mese · '
                    'Prossimo azzeramento: ${_nextResetLabel()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Top utenti del mese 🔥',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          // Lista della classifica da Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Ordiniamo gli utenti in base ai punti (dall'alto verso il basso)
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('points', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nessun utente in classifica al momento.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData =
                        users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;
                    final isMe =
                        currentUser != null && userId == currentUser.uid;

                    final name =
                        userData['name'] ?? userData['firstName'] ?? 'Utente';
                    final points = userData['points'] ?? 0;
                    final level = userData['level'] ?? 'Profilo attivo';
                    // La foto può essere un link http oppure un testo base64:
                    // PhotoUtils gestisce entrambi senza mandare in crash l'app.
                    final ImageProvider? photoProvider = PhotoUtils.provider(
                        (userData['profilePhotoUrl'] ?? userData['photo'] ?? '')
                            .toString());

                    // Colori speciali per il podio (1°, 2°, 3°)
                    Color? rankColor;
                    if (index == 0) rankColor = Colors.amber.shade200; // Oro
                    if (index == 1) rankColor = Colors.grey.shade300; // Argento
                    if (index == 2) rankColor = Colors.brown.shade200; // Bronzo

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.purple.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMe ? Colors.purple : Colors.grey.shade200,
                          width: isMe ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Stack(
                          children: [
                            // Foto profilo reale (se presente) o cerchio con colore del podio
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  rankColor ?? Colors.purple.shade100,
                              backgroundImage: photoProvider,
                              child: photoProvider == null
                                  ? Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: rankColor != null
                                            ? Colors.black87
                                            : Colors.purple,
                                      ),
                                    )
                                  : null,
                            ),
                            // Piccolo badge con la posizione se c'è la foto reale
                            if (photoProvider != null)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: rankColor ?? Colors.purple,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          isMe ? '$name (Tu)' : name,
                          style: TextStyle(
                            fontWeight:
                                isMe ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('Livello: $level'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$points pt',
                            style: TextStyle(
                              color: Colors.purple.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Data del prossimo azzeramento (il 15 del mese, a mezzanotte).
String _nextResetLabel() {
  const months = [
    'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
    'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'
  ];
  final now = DateTime.now();
  final next = now.day < 15
      ? DateTime(now.year, now.month, 15)
      : DateTime(now.year, now.month + 1, 15);
  return '15 ${months[next.month - 1]}';
}

class _PrizeLine extends StatelessWidget {
  final String icon;
  final String text;
  const _PrizeLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Text(
        '$icon  $text',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}
