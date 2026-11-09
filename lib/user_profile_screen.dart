import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'photo_utils.dart';
import 'premium_screen.dart';

/// Schermata di dettaglio del profilo di un altro utente.
///
/// Regole foto:
/// - Utenti free/standard: vedono le prime [freeVisiblePhotos] foto,
///   le altre sono sfocate e bloccate (tap → schermata Premium).
/// - Utenti Premium: vedono e aprono tutte le foto caricate.
/// - Il proprietario del profilo vede sempre tutte le sue foto.
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  /// Numero di foto (inclusa la principale) visibili agli utenti non Premium.
  static const int freeVisiblePhotos = 2;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Raccoglie tutte le foto del profilo: principale + galleria.
  /// Legge sia 'galleryPhotos' (campo usato dal salvataggio profilo)
  /// sia 'gallery' (vecchio nome), scarta i link 'blob:' non validi
  /// e rimuove i duplicati mantenendo l'ordine.
  List<String> _collectPhotos(Map<String, dynamic> data) {
    final List<String> result = [];
    void add(dynamic value) {
      if (value is! String) return;
      final p = value.trim();
      if (p.isEmpty || p.startsWith('blob:') || result.contains(p)) return;
      result.add(p);
    }

    add(data['profilePhotoUrl'] ?? data['photo']);
    for (final key in ['galleryPhotos', 'gallery']) {
      final list = data[key];
      if (list is List) {
        for (final item in list) {
          add(item);
        }
      }
    }
    return result;
  }

  bool _readPremium(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['isPremium'] == true || data['vip'] == true;
  }

  void _openPremium() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Questa foto è esclusiva per i membri Premium! 🔒'),
        backgroundColor: Colors.orange,
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PremiumScreen()),
    );
  }

  void _openViewer(List<String> unlockedPhotos, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewer(
          photos: unlockedPhotos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ascolta in tempo reale lo stato Premium di chi sta guardando:
    // appena l'utente si abbona, le foto si sbloccano senza ricaricare.
    final Stream<DocumentSnapshot<Map<String, dynamic>>>? visitorStream =
        currentUserId.isEmpty
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo Utente'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: visitorStream,
        builder: (context, visitorSnap) {
          final bool isVisitorPremium = _readPremium(visitorSnap.data?.data());
          final bool isOwnProfile = currentUserId == widget.userId;
          final bool canSeeAll = isVisitorPremium || isOwnProfile;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final userData = snapshot.data?.data();
              if (userData == null) {
                return const Center(child: Text('Profilo non trovato.'));
              }

              final String name =
                  userData['firstName'] ?? userData['name'] ?? 'Utente';
              final dynamic rawAge =
                  userData['age'] ?? userData['eta'] ?? userData['birthYear'];
              final int age = rawAge is int
                  ? rawAge
                  : int.tryParse(rawAge?.toString() ?? '') ?? 0;
              final String bio = userData['bio'] ??
                  userData['status'] ??
                  'Nessuna bio inserita.';

              final List<String> photos = _collectPhotos(userData);
              final int unlockedCount = canSeeAll
                  ? photos.length
                  : photos.length.clamp(0, UserProfileScreen.freeVisiblePhotos);
              final int lockedCount = photos.length - unlockedCount;
              final List<String> unlockedPhotos =
                  photos.sublist(0, unlockedCount);

              bool isLocked(int index) => index >= unlockedCount;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- CAROSELLO FOTO ---
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 380,
                        width: double.infinity,
                        child: photos.isEmpty
                            ? Container(
                                color: Colors.purple[50],
                                child: const Icon(Icons.person,
                                    size: 100, color: Colors.purple),
                              )
                            : Stack(
                                children: [
                                  PageView.builder(
                                    controller: _pageController,
                                    itemCount: photos.length,
                                    onPageChanged: (i) =>
                                        setState(() => _currentPage = i),
                                    itemBuilder: (context, index) {
                                      return _PhotoTile(
                                        photo: photos[index],
                                        locked: isLocked(index),
                                        bigLock: true,
                                        onTap: () => isLocked(index)
                                            ? _openPremium()
                                            : _openViewer(
                                                unlockedPhotos, index),
                                      );
                                    },
                                  ),
                                  // Indicatori pagina
                                  if (photos.length > 1)
                                    Positioned(
                                      top: 10,
                                      left: 12,
                                      right: 12,
                                      child: Row(
                                        children: List.generate(
                                          photos.length,
                                          (i) => Expanded(
                                            child: Container(
                                              height: 3,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 2),
                                              decoration: BoxDecoration(
                                                color: i == _currentPage
                                                    ? Colors.white
                                                    : Colors.white38,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Contatore foto
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${_currentPage.clamp(0, photos.length - 1) + 1}/${photos.length}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

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

                    Row(
                      children: [
                        Text(
                          'Galleria Fotografica (${photos.length})',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (isVisitorPremium && !isOwnProfile)
                          const Chip(
                            avatar: Icon(Icons.workspace_premium,
                                color: Colors.amber, size: 18),
                            label: Text('Premium'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Banner sblocco per utenti free
                    if (lockedCount > 0) ...[
                      InkWell(
                        onTap: _openPremium,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.purple.shade400,
                              Colors.deepPurple.shade600,
                            ]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_open,
                                  color: Colors.amber),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  lockedCount == 1
                                      ? 'Sblocca 1 altra foto con Premium'
                                      : 'Sblocca altre $lockedCount foto con Premium',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    photos.isEmpty
                        ? const Text('Nessuna foto nella galleria.',
                            style: TextStyle(color: Colors.grey))
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                            itemCount: photos.length,
                            itemBuilder: (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _PhotoTile(
                                  photo: photos[index],
                                  locked: isLocked(index),
                                  bigLock: false,
                                  onTap: () {
                                    if (isLocked(index)) {
                                      _openPremium();
                                    } else {
                                      _pageController.animateToPage(
                                        index,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                      _openViewer(unlockedPhotos, index);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Singola foto, eventualmente sfocata e coperta dal lucchetto Premium.
class _PhotoTile extends StatelessWidget {
  final String photo;
  final bool locked;
  final bool bigLock;
  final VoidCallback onTap;

  const _PhotoTile({
    required this.photo,
    required this.locked,
    required this.bigLock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = PhotoUtils.image(
      photo,
      placeholder: Container(
        color: Colors.purple[50],
        child: const Icon(Icons.broken_image, color: Colors.purple),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (locked)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: image,
            )
          else
            image,
          if (locked)
            Container(
              color: Colors.black.withOpacity(0.45),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock,
                      color: Colors.amber, size: bigLock ? 48 : 28),
                  const SizedBox(height: 6),
                  Text(
                    bigLock ? 'Sblocca con Premium' : 'Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: bigLock ? 16 : 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Visualizzatore a schermo intero (solo foto sbloccate), con zoom.
class _PhotoViewer extends StatelessWidget {
  final List<String> photos;
  final int initialIndex;

  const _PhotoViewer({required this.photos, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photos.length,
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: PhotoUtils.image(photos[index], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
