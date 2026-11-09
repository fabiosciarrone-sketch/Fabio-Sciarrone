import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_screen.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Se l'utente non è loggato, mostra solo la campanella normale
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.notifications, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationScreen()),
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      // Ascolta in tempo reale le notifiche non lette dell'utente corrente
      stream: FirebaseFirestore.instance
          .collection(
              'notifications') // Assicurati che corrisponda alla tua collezione su Firestore
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false) // Filtra quelle non ancora lette
          .snapshots(),
      builder: (context, snapshot) {
        // In caso di errore (es. permessi negati) il contatore va a 0
        // e la campanella resta comunque cliccabile.
        int unreadCount = 0;
        if (snapshot.hasError) {
          debugPrint('Campanella: impossibile leggere le notifiche: '
              '${snapshot.error}');
        } else if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.length;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationScreen(),
                  ),
                );
              },
            ),
            // Mostra il badge numerico rosso solo se ci sono notifiche non lette (> 0)
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
