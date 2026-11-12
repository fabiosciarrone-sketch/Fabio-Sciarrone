import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ticket_ad_service.dart';

class EventiDelGiornoScreen extends StatelessWidget {
  final String currentCity;

  const EventiDelGiornoScreen({super.key, required this.currentCity});

  @override
  Widget build(BuildContext context) {
    Future<void> _openTicketUrl(urlString) async {
      if (urlString == null || urlString.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Nessun link di acquisto disponibile per questo evento.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Mostra l'annuncio a tutto schermo; il link si apre solo dopo la chiusura
      await TicketAdService.showBeforeLeaving();

      final Uri url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossibile aprire il link dell\'evento.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Eventi del Giorno a $currentCity 🗓️'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('events').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Errore nel caricamento degli eventi.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('Nessun evento disponibile al momento.'),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final eventData = docs[index].data() as Map<String, dynamic>;

              // Leggiamo i campi con i nomi esatti che hai su Firebase
              final title = eventData['title'] ?? 'Evento';
              final location = eventData['locationName'] ?? '';
              final time = eventData['date'] ?? '';
              final ticketUrl = eventData['ticketUrl'] ?? '';
              final imageUrl = eventData['imageUrl'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 60,
                              height: 60,
                              color: Colors.purple.shade100,
                              child:
                                  const Icon(Icons.event, color: Colors.purple),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.purple.shade100,
                            child:
                                const Icon(Icons.event, color: Colors.purple),
                          ),
                  ),
                  title: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('📍 $location • ⏰ $time',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      const Text(
                        '🎟️ Biglietti Ufficiali TicketOne',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ],
                  ),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    onPressed: () => _openTicketUrl(ticketUrl),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label:
                        const Text('Acquista', style: TextStyle(fontSize: 12)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
