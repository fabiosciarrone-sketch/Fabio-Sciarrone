import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

/// Elenco delle notifiche dell'utente (salvate dalla Cloud Function).
/// All'apertura segna tutte le notifiche come lette, così il numero
/// sulla campanella torna a zero.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  Stream<QuerySnapshot>? _stream;

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      // Nessun orderBy: l'ordinamento lo facciamo nell'app, così non serve
      // creare un indice composto su Firestore.
      _stream = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _uid)
          .snapshots();
      _markAllAsRead();
    }
  }

  Future<void> _markAllAsRead() async {
    // Gestisce da sola gli errori di permessi: non blocca mai la schermata.
    await NotificationService.markAllNotificationsAsRead();
  }

  static DateTime _date(Map<String, dynamic> data) {
    final ts = data['createdAt'];
    if (ts is Timestamp) return ts.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatDate(DateTime d) {
    if (d.millisecondsSinceEpoch == 0) return '';
    final now = DateTime.now();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Oggi alle $hh:$mm';
    }
    return '${d.day}/${d.month}/${d.year} $hh:$mm';
  }

  static IconData _iconFor(String? type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'super_like':
        return Icons.diamond;
      case 'message':
        return Icons.chat_bubble;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _stream == null
          ? const Center(child: Text('Accedi per vedere le notifiche'))
          : StreamBuilder<QuerySnapshot>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final denied =
                      NotificationService.isPermissionDenied(snapshot.error!);
                  debugPrint('Errore lettura notifiche: ${snapshot.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_off,
                              size: 56, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            denied
                                ? 'Le notifiche non sono disponibili al momento.'
                                : 'Impossibile caricare le notifiche. Riprova più tardi.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = (snapshot.data?.docs ?? []).toList()
                  ..sort((a, b) => _date(b.data() as Map<String, dynamic>)
                      .compareTo(_date(a.data() as Map<String, dynamic>)));

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Nessuna notifica per ora',
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isRead = data['isRead'] == true;
                    return ListTile(
                      tileColor: isRead ? null : Colors.purple.shade50,
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.shade100,
                        child: Icon(_iconFor(data['type']?.toString()),
                            color: Colors.purple),
                      ),
                      title: Text(
                        (data['title'] ?? 'Notifica').toString(),
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text((data['body'] ?? '').toString()),
                      trailing: Text(
                        _formatDate(_date(data)),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
