import 'package:flutter/material.dart';

class PresenceScreen extends StatefulWidget {
  const PresenceScreen({super.key});

  @override
  State<PresenceScreen> createState() => _PresenceScreenState();
}

class _PresenceScreenState extends State<PresenceScreen> {
  final List<Map<String, String>> _users = [
    {
      'name': 'Marco Rossi',
      'role': 'Developer',
      'city': 'Roma',
      'bio': 'Appassionato di Flutter e Mobile Apps.',
    },
    {
      'name': 'Sara Bianchi',
      'role': 'Designer',
      'city': 'Milano',
      'bio': 'UX/UI Designer con la passione per la grafica.',
    },
    {
      'name': 'Luca Verdi',
      'role': 'Project Manager',
      'city': 'Napoli',
      'bio': 'Gestione team e coordinamento progetti tech.',
    },
  ];

  // Metodo per mostrare i dettagli dell'utente
  void showUserDetailDialog(Map<String, String> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name'] ?? 'Dettagli Utente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ruolo: ${user['role']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Città: ${user['city']}'),
            const SizedBox(height: 8),
            Text('Bio: ${user['bio']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presenze e Utenti'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(
                  user['name']![0],
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                user['name']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${user['role']} • ${user['city']}'),
              trailing: const Icon(
                Icons.info_outline,
                color: Colors.deepPurple,
              ),
              onTap: () => showUserDetailDialog(user),
            ),
          );
        },
      ),
    );
  }
}
