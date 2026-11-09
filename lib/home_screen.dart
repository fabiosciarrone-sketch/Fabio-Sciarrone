import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'around_me_screen.dart';
import 'qr_screen.dart';
import 'chat_list_screen.dart';
import 'premium_screen.dart';
import 'community_locali_screen.dart';
import 'chat_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'user_grid_widget.dart';
import 'reviews_screen.dart';
import 'leaderboard_screen.dart';
import 'offers_list_screen.dart';
import 'eventi_del_giorno_screen.dart';
import 'notification_bell.dart';
import 'photo_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userCity = '';
  LatLng _currentPosition =
      const LatLng(37.507877, 15.083030); // Coordinate predefinite (Catania)
  bool _isLoadingLocation = true;

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    }
  }

  bool _isVisible = true;
  int userHearts = 0;
  int userDiamonds = 0;
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  int _currentIndex = 0;

  // Stream dei messaggi non letti ricevuti dall'utente corrente.
  // Creato una sola volta in initState, così non si riapre a ogni rebuild.
  Stream<QuerySnapshot>? _unreadMessagesStream;

  final List<Map<String, dynamic>> _stories = [
    {
      'name': 'Sofia',
      'image':
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500',
      'online': true
    },
    {
      'name': 'Lorenzo',
      'image':
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=500',
      'online': true
    },
    {
      'name': 'Martina',
      'image':
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500',
      'online': false
    },
    {
      'name': 'Davide',
      'image':
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500',
      'online': true
    },
    {
      'name': 'Chiara',
      'image':
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=500',
      'online': true
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserCityInBackground();
    _loadVisibilityStatus();
    _listenToUserWallet();
    _determinePosition();
    if (currentUserId.isNotEmpty) {
      _unreadMessagesStream = FirebaseFirestore.instance
          .collectionGroup('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .snapshots();
    }
  }

// --- SEZIONE EVENTI REALI DEL GIORNO E COMMUNITY ---
  Widget _buildRealEventsSection() {
    final String currentCity = userCity.isNotEmpty ? userCity : 'Catania';

    return Column(
      children: [
        // 1. Banner degli Eventi Cliccabile
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    EventiDelGiornoScreen(currentCity: currentCity),
              ),
            );
          },
          child: _GlassCard(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_HomeColors.violet, _HomeColors.pink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _HomeColors.violet.withOpacity(0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.calendar_today,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eventi del Giorno a $currentCity 📅',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scopri tutti gli eventi e acquista i biglietti ufficiali',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.65)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.7), size: 16),
              ],
            ),
          ),
        ),

        // 2. Pulsante rapido per la Community
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CommunityLocaliScreen(),
                ),
              );
            },
            child: _GlassCard(
              radius: 16,
              tint: _HomeColors.violet,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, color: _HomeColors.lilac, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Accedi alla Community Locale 🌍',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _listenToUserWallet() {
    if (currentUserId.isEmpty) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          userHearts = data['hearts'] ?? 0;
          userDiamonds = data['diamonds'] ?? 0;
        });
      }
    });
  }

  Future<void> _loadUserCityInBackground() async {
    try {
      if (currentUserId.isNotEmpty) {
        DocumentSnapshot doc;
        try {
          doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get();
        } catch (e) {
          doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get(const GetOptions(source: Source.cache));
        }
        if (doc.exists && doc.data() != null && mounted) {
          final data = doc.data() as Map<String, dynamic>?;
          setState(() {
            userCity = data?['city'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint("Errore caricamento città: $e");
    }
  }

  Future<void> _loadVisibilityStatus() async {
    try {
      if (currentUserId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        if (doc.exists && doc.data() != null && mounted) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _isVisible = data['isVisible'] ?? true;
          });
        }
      }
    } catch (e) {
      debugPrint("Errore caricamento visibilità: $e");
    }
  }

  Future<void> _updateVisibilityStatus(bool value) async {
    setState(() {
      _isVisible = value;
    });
    try {
      if (currentUserId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .set({
          'isVisible': value,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Errore salvataggio visibilità: $e");
    }
  }

  void _onItemTapped(int index) {
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PremiumScreen()),
      );
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _sendLike(String receiverId, String receiverName) async {
    if (userHearts <= 0) {
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

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set({
        'hearts': FieldValue.increment(-1),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Hai mandato un cuoricino a $receiverName ❤️ (-1 Cuore)'),
          backgroundColor: Colors.pink,
        ),
      );

      await FirebaseFirestore.instance.collection('likes').add({
        'senderId': currentUserId,
        'receiverId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // --- SCRITTURA DEL MESSAGGIO NELLA CHAT (AGGIUNTO QUI) ---
      List<String> chatIds = [currentUserId, receiverId];
      chatIds.sort();
      String chatId = chatIds.join('_');
      print(">>> DEBUG CHAT ID: $chatId");

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'text': '❤ Ha inviato un Super Like!',
        'timestamp': FieldValue.serverTimestamp(),
        'isSuperLike': true,
        'receiverId': receiverId,
        'isRead': false,
      });

      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'lastMessage': '❤ Ha inviato un Super Like!',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'participants': [
          currentUserId,
          receiverId
        ], // <--- UNICA AGGIUNTA FATTA QUI
      }, SetOptions(merge: true));
      // --------------------------------------------------------

      // --- Controllo Match Reciproco ---
      var reverseLikeDoc = await FirebaseFirestore.instance
          .collection('likes')
          .where('senderId', isEqualTo: receiverId)
          .where('receiverId', isEqualTo: currentUserId)
          .get();

      if (reverseLikeDoc.docs.isNotEmpty) {
        // C'è il Match! Mostriamo il pop-up celebrativo
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "È un Match! 🎉",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Immagine dell'incrocio / profili uniti
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
                      height: 150,
                      width: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Tu e $receiverName vi siete piaciuti a vicenda!",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Chiude il pop-up
                      _openChat(receiverId,
                          receiverName); // <--- AGGIUNTO: Apre direttamente la chat!
                    },
                    child: const Text(
                      "Inizia a chattare",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      print(">>> ERRORE NELLO SENDLIKE: $e");
      debugPrint("Errore durante l'invio del like o controllo del match: $e");
    }
  }

  void _openChat(String receiverId, String receiverName) {
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join('_');

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

  void _showUserProfileModal(String userId, Map<String, dynamic> userData,
      String name, String? photo) {
    final List<dynamic> interests = userData['interests'] ?? [];
    final String city = userData['city'] ?? userCity;
    final bool isPremium = userData['isPremium'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: PhotoUtils.image(
                          photo,
                          height: 320,
                          width: double.infinity,
                          placeholder: Container(
                            height: 320,
                            width: double.infinity,
                            color: Colors.purple[50],
                            child: const Icon(Icons.person,
                                size: 100, color: Colors.purple),
                          ),
                        ),
                      ),
                      if (isPremium)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.star, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'PREMIUM',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (city.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.location_on,
                              size: 16, color: Colors.purple),
                          label: Text(city),
                          backgroundColor: Colors.purple.shade50,
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
  }

  Widget _buildHomeContent() {
    return _HomeBackground(
      child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // 1. Sezione Eventi TicketOne
          _buildRealEventsSection(),

          const SizedBox(height: 12),

          // 2. Banner Offerta del Giorno
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const OffersListScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _HomeColors.violet.withOpacity(0.85),
                    _HomeColors.pink.withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
                boxShadow: [
                  BoxShadow(
                    color: _HomeColors.pink.withOpacity(0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Text('🔥', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offerta del Giorno!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Sconto 20% nei locali partner per i membri Premium!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 3. Box Profilo Visibile
          _GlassCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isVisible
                                ? _HomeColors.mint
                                : Colors.white)
                            .withOpacity(0.14),
                      ),
                      child: Icon(
                        _isVisible ? Icons.visibility : Icons.visibility_off,
                        color: _isVisible
                            ? _HomeColors.mint
                            : Colors.white.withOpacity(0.6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isVisible
                              ? 'Profilo Visibile'
                              : 'Profilo Invisibile',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                        Text(
                          _isVisible
                              ? 'Gli altri ti vedono'
                              : 'Risulti nascosto',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _isVisible,
                  activeColor: Colors.white,
                  activeTrackColor: _HomeColors.violet,
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white.withOpacity(0.15),
                  onChanged: _updateVisibilityStatus,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [_HomeColors.violet, _HomeColors.pink],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Persone nelle vicinanze',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. La griglia degli utenti isolata
          const UserGridWidget(),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }

  /// Icona Chat con il numero di messaggi non letti.
  /// Se non ci sono messaggi da leggere (o la query non è disponibile)
  /// viene mostrata solo l'icona, senza pallino rosso.
  Widget _buildChatIconWithBadge() {
    if (_unreadMessagesStream == null) return const Icon(Icons.chat);

    return StreamBuilder<QuerySnapshot>(
      stream: _unreadMessagesStream,
      builder: (context, snapshot) {
        // Se la query fallisce (permessi negati, indice mancante, rete...)
        // il badge si azzera: mostriamo solo l'icona, senza pallino rosso.
        if (snapshot.hasError) {
          debugPrint('Badge chat disattivato, errore conteggio messaggi non '
              'letti: ${snapshot.error}');
          return const Icon(Icons.chat);
        }

        final int unreadCount =
            snapshot.hasData ? snapshot.data!.docs.length : 0;

        if (unreadCount <= 0) {
          return const Icon(Icons.chat);
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.chat),
            Positioned(
              right: -8,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeContent(),
      const AroundMeScreen(),
      const ChatListScreen(),
      const PremiumScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: _currentIndex == 0 ? _HomeColors.bgTop : null,
      appBar: AppBar(
        title: const Text(
          'Home',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
        backgroundColor: _HomeColors.bgTop,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_HomeColors.bgTop, _HomeColors.bgMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
        ),
        actions: [
          const NotificationBell(),
          // Questo è il tuo pulsante della coppa che c'è già:
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.amber),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeaderboardScreen(),
                ),
              );
            },
            tooltip: 'Classifica & Premi',
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
        child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: _HomeColors.bgTop,
        elevation: 0,
        selectedItemColor: _HomeColors.lilac,
        unselectedItemColor: Colors.white.withOpacity(0.5),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Around Me',
          ),
          BottomNavigationBarItem(
            // Il badge rosso compare SOLO se ci sono messaggi non letti
            icon: _buildChatIconWithBadge(),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Premium',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
      ),
    );
  }
}

// ===================================================================
// STILE HOME: palette scura/violacea + card glassmorphism
// (solo estetica, nessuna logica)
// ===================================================================

class _HomeColors {
  _HomeColors._();
  static const Color bgTop = Color(0xFF0E0820);
  static const Color bgMid = Color(0xFF1B1035);
  static const Color bgBottom = Color(0xFF2A1250);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color lilac = Color(0xFFC4B5FD);
  static const Color pink = Color(0xFFEC4899);
  static const Color mint = Color(0xFF6EE7B7);
}

/// Sfondo sfumato scuro con due aloni luminosi violacei.
class _HomeBackground extends StatelessWidget {
  final Widget child;
  const _HomeBackground({required this.child});

  Widget _glow(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.35), color.withOpacity(0.0)],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _HomeColors.bgTop,
            _HomeColors.bgMid,
            _HomeColors.bgBottom
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -80, right: -60, child: _glow(_HomeColors.violet, 280)),
          Positioned(top: 260, left: -100, child: _glow(_HomeColors.pink, 260)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Card "vetro smerigliato": sfocatura dello sfondo, riempimento
/// semitrasparente, bordo chiaro sottile e angoli morbidi.
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;

  const _GlassCard({
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final Color base = tint ?? Colors.white;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                colors: [
                  base.withOpacity(tint != null ? 0.22 : 0.12),
                  base.withOpacity(tint != null ? 0.08 : 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.16),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
