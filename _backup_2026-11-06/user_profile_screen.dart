import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'photo_utils.dart';
import 'premium_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool isCurrentVisitorPremium = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentVisitorPremiumStatus();
  }

  Future<void> _checkCurrentVisitorPremiumStatus() async {
    if (currentUserId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          isCurrentVisitorPremium =
              doc.data()?['isPremium'] ?? doc.data()?['vip'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Errore controllo premium: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo Utente'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.data() == null) {
            return const Center(child: Text('Profilo non trovato.'));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String name = userData['firstName'] ?? userData['name'] ?? 'Utente';

          // Controlla diverse varianti del campo età salvato su Firestore
          int age =
              userData['age'] ?? userData['eta'] ?? userData['birthYear'] ?? 0;

          String bio =
              userData['bio'] ?? userData['status'] ?? 'Nessuna bio inserita.';
          String mainPhoto =
              userData['profilePhotoUrl'] ?? userData['photo'] ?? '';

          List<dynamic> galleryPhotos = userData['gallery'] ?? [];
          if (mainPhoto.isNotEmpty && !galleryPhotos.contains(mainPhoto)) {
            galleryPhotos.insert(0, mainPhoto);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: PhotoUtils.image(
                    mainPhoto,
                    height: 350,
                    width: double.infinity,
                    placeholder: Container(
                      height: 350,
                      width: double.infinity,
                      color: Colors.purple[50],
                      child: const Icon(Icons.person,
                          size: 100, color: Colors.purple),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Mostra Nome ed Età (se maggiore di 0)
                Text(
                  age > 0 ? '$name, $age' : name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Bio:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(bio, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                const Text(
                  'Galleria Fotografica',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                galleryPhotos.isEmpty
                    ? const Text('Nessuna foto nella galleria.',
                        style: TextStyle(color: Colors.grey))
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemCount: galleryPhotos.length,
                        itemBuilder: (context, index) {
                          String photoData = galleryPhotos[index];
                          bool isLocked =
                              index >= 2 && !isCurrentVisitorPremium;

                          return GestureDetector(
                            onTap: () {
                              if (isLocked) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Questa foto è esclusiva per i membri Premium! 🔒'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const PremiumScreen()),
                                );
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  PhotoUtils.image(
                                    photoData,
                                    placeholder: Container(
                                      color: Colors.purple[50],
                                      child: const Icon(Icons.broken_image,
                                          color: Colors.purple),
                                    ),
                                  ),
                                  if (isLocked)
                                    Container(
                                      color: Colors.black.withOpacity(0.65),
                                      child: const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.lock,
                                              color: Colors.amber, size: 36),
                                          SizedBox(height: 6),
                                          Text(
                                            'Premium',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
