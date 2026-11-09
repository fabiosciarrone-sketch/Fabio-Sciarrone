import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class VenueDetailScreen extends StatefulWidget {
  final String venueId;
  final String venueName;

  const VenueDetailScreen({
    Key? key,
    required this.venueId,
    required this.venueName,
  }) : super(key: key);

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool isCheckedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    if (currentUserId.isEmpty) return;
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (!mounted) return; // Controllo di sicurezza post-await
      if (doc.exists && doc.data() != null) {
        String? activeVenue = doc.data()!['checkedInVenueId'];
        setState(() {
          isCheckedIn = (activeVenue == widget.venueId);
        });
      }
    } catch (e) {
      debugPrint("Errore controllo check-in: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCheckIn() async {
    if (currentUserId.isEmpty) return;
    try {
      setState(() {
        _isLoading = true;
      });

      if (isCheckedIn) {
        // Rimuovi check-in
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({
          'checkedInVenueId': FieldValue.delete(),
        });

        // 👉 Controllo aggiunto qui per evitare use_build_context_synchronously
        if (!mounted) return;

        setState(() {
          isCheckedIn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Hai effettuato il check-out dal locale.'),
              backgroundColor: Colors.orange),
        );
      } else {
        // Effettua check-in
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({
          'checkedInVenueId': widget.venueId,
        });

        // 👉 Controllo aggiunto qui per evitare use_build_context_synchronously
        if (!mounted) return;

        setState(() {
          isCheckedIn = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Check-in effettuato a ${widget.venueName}! 🎉'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Errore toggle check-in: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.venueName,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bottone di Check-in / Check-out in alto
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.purple.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sei qui in questo momento?',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                            isCheckedIn
                                ? 'Sei attualmente qui ✅'
                                : 'Fai check-in per farti vedere dagli altri',
                            style: TextStyle(
                                color: isCheckedIn ? Colors.green : Colors.grey,
                                fontSize: 13),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isCheckedIn ? Colors.red : Colors.purple,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _toggleCheckIn,
                        child: Text(
                          isCheckedIn ? 'Lascia Locale' : 'Fai Check-in 📍',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Sezione Persone Presenti
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: const [
                      Icon(Icons.people, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Persone qui adesso',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('checkedInVenueId', isEqualTo: widget.venueId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var presentUsers = snapshot.data!.docs;

                      if (presentUsers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.person_off,
                                  size: 60, color: Colors.grey),
                              SizedBox(height: 12),
                              Text(
                                'Nessun utente qui in questo momento.\nSii il primo a fare check-in!',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: presentUsers.length,
                        itemBuilder: (context, index) {
                          var userData = presentUsers[index].data()
                              as Map<String, dynamic>;
                          String name = userData['name'] ?? 'Utente';
                          String? photo = userData['photoUrl'];
                          String bio = userData['bio'] ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.purple.shade100,
                                backgroundImage:
                                    photo != null && photo.isNotEmpty
                                        ? (photo.startsWith('data:')
                                            ? MemoryImage(base64Decode(
                                                    photo.split(',').last))
                                                as ImageProvider
                                            : NetworkImage(photo))
                                        : null,
                                child: (photo == null || photo.isEmpty)
                                    ? const Icon(Icons.person,
                                        color: Colors.purple)
                                    : null,
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  bio.isNotEmpty ? bio : 'Nessuna bio',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(Icons.favorite,
                                    color: Colors.red),
                                onPressed: () {
                                  // Azione like rapido o chat
                                },
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
