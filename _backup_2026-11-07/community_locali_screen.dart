import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class CommunityLocaliScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialPlaceName;

  const CommunityLocaliScreen({
    super.key,
    this.initialCategory,
    this.initialPlaceName,
  });

  @override
  State<CommunityLocaliScreen> createState() => _CommunityLocaliScreenState();
}

class _CommunityLocaliScreenState extends State<CommunityLocaliScreen> {
  final List<Map<String, dynamic>> categories = const [
    {
      'title': 'Teatro',
      'icon': Icons.theater_comedy,
      'color': Colors.purple,
      'image':
          'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=500',
    },
    {
      'title': 'Cinema',
      'icon': Icons.movie,
      'color': Colors.orange,
      'image':
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=500',
    },
    {
      'title': 'Palestra',
      'icon': Icons.fitness_center,
      'color': Colors.indigo,
      'image':
          'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=500',
    },
    {
      'title': 'Bar',
      'icon': Icons.local_bar,
      'color': Colors.amber,
      'image':
          'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=500',
    },
    {
      'title': 'Ristoranti',
      'icon': Icons.restaurant,
      'color': Colors.deepOrange,
      'image':
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500',
    },
    {
      'title': 'Eventi Locali',
      'icon': Icons.event,
      'color': Colors.blue,
      'image':
          'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500',
    },
    {
      'title': 'Gruppi & Social',
      'icon': Icons.group,
      'color': Colors.green,
      'image':
          'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=500',
    },
    {
      'title': 'Musica & Live',
      'icon': Icons.music_note,
      'color': Colors.red,
      'image':
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
    },
    {
      'title': 'Sport & Attività',
      'icon': Icons.sports_soccer,
      'color': Colors.teal,
      'image':
          'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=500',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final matchedCategory = categories.firstWhere(
          (cat) => cat['title']
              .toString()
              .toLowerCase()
              .contains(widget.initialCategory!.toLowerCase()),
          orElse: () => categories.first,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryDetailScreen(
              categoryTitle: matchedCategory['title'],
              categoryColor: matchedCategory['color'],
              categoryIcon: matchedCategory['icon'],
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Community SideBySide',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esplora categorie e gruppi',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CategoryDetailScreen(
                              categoryTitle: cat['title'],
                              categoryColor: cat['color'],
                              categoryIcon: cat['icon'],
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            cat['image'],
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  (cat['color'] as Color).withOpacity(0.4),
                                  Colors.black.withOpacity(0.85),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(cat['icon'],
                                    size: 36, color: Colors.white),
                                const SizedBox(height: 8),
                                Text(
                                  cat['title'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryDetailScreen extends StatefulWidget {
  final String categoryTitle;
  final Color categoryColor;
  final IconData categoryIcon;

  const CategoryDetailScreen({
    super.key,
    required this.categoryTitle,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  Position? _userPosition;
  List<Map<String, dynamic>> _dynamicPlaces = [];

  @override
  void initState() {
    super.initState();
    _initDefaultPlaces(37.5079, 15.0830);
    _determinePositionInBackground();
  }

  Future<void> _determinePositionInBackground() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _userPosition = position;
          _initDefaultPlaces(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint("Errore GPS: $e");
    }
  }

  void _initDefaultPlaces(double lat, double lon) {
    final title = widget.categoryTitle;
    _dynamicPlaces = [
      {
        'name': '$title Centrale',
        'description': 'Punto di ritrovo principale per $title nella tua zona.',
        'latitude': lat + 0.002,
        'longitude': lon + 0.002,
        'membersCount': 1,
      },
      {
        'name': '$title Hub & Social',
        'description':
            'Spazio di aggregazione e incontri organizzati dalla community.',
        'latitude': lat - 0.003,
        'longitude': lon + 0.001,
        'membersCount': 1,
      },
    ];
  }

  void _showAddPlaceDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(widget.categoryIcon, color: widget.categoryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Crea stanza ${widget.categoryTitle}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome Locale / Stanza (es. Up Level)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Breve descrizione',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.categoryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              // Prendiamo Navigator e ScaffoldMessenger PRIMA delle operazioni
              // asincrone e della chiusura del dialog, così non usiamo un
              // context non più valido.
              final navigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(dialogContext);

              try {
                final user = FirebaseAuth.instance.currentUser;

                await FirebaseFirestore.instance.collection('places').add({
                  'name': nameController.text.trim(),
                  'category': widget.categoryTitle,
                  'description': descController.text.trim().isNotEmpty
                      ? descController.text.trim()
                      : 'Nuovo punto di ritrovo creato dalla community.',
                  'latitude': _userPosition?.latitude ?? 37.5079,
                  'longitude': _userPosition?.longitude ?? 15.0830,
                  'membersCount': 1,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // 🏆 Assegna +15 punti per aver creato un nuovo locale / stanza
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({
                    'points': FieldValue.increment(15),
                  }, SetOptions(merge: true));
                }

                // Chiude il dialog solo se è ancora aperto
                if (dialogContext.mounted) navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Stanza creata! +15 Punti Guadagnati 🏆'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Errore durante la creazione: $e')),
                );
              }
            },
            child: const Text('Crea', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _calculateDistance(double? destLat, double? destLon) {
    if (_userPosition == null || destLat == null || destLon == null) {
      return 'Vicino a te';
    }
    double distanceInMeters = Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      destLat,
      destLon,
    );
    if (distanceInMeters >= 1000) {
      double km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)} km di distanza';
    } else {
      return '${distanceInMeters.toStringAsFixed(0)}m di distanza';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: widget.categoryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('places')
            .where('category', isEqualTo: widget.categoryTitle)
            .snapshots(),
        builder: (context, snapshot) {
          var docs = snapshot.data?.docs ?? [];
          final bool hasFirestoreData = docs.isNotEmpty;
          final int itemCount =
              hasFirestoreData ? docs.length : _dynamicPlaces.length;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              String name;
              String description;
              double? lat;
              double? lon;
              int membersCount;

              if (hasFirestoreData) {
                final data = docs[index].data() as Map<String, dynamic>;
                name = data['name'] ?? widget.categoryTitle;
                description = data['description'] ?? 'Punto di riferimento.';
                lat = data['latitude'];
                lon = data['longitude'];
                membersCount = data['membersCount'] ?? 1;
              } else {
                final data = _dynamicPlaces[index];
                name = data['name'];
                description = data['description'];
                lat = data['latitude'];
                lon = data['longitude'];
                membersCount = data['membersCount'];
              }

              final distanceText = _calculateDistance(lat, lon);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: widget.categoryColor.withOpacity(0.2),
                    child:
                        Icon(widget.categoryIcon, color: widget.categoryColor),
                  ),
                  title: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(description,
                          style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            distanceText,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.person,
                              size: 14, color: widget.categoryColor),
                          const SizedBox(width: 4),
                          Text(
                            '$membersCount partecipanti',
                            style: TextStyle(
                                color: widget.categoryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.categoryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaceCommunityDetailScreen(
                            placeName: name,
                            categoryTitle: widget.categoryTitle,
                            categoryColor: widget.categoryColor,
                            categoryIcon: widget.categoryIcon,
                          ),
                        ),
                      );
                    },
                    child: const Text('Unisciti',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: widget.categoryColor,
        onPressed: () => _showAddPlaceDialog(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Crea Stanza', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class PlaceCommunityDetailScreen extends StatefulWidget {
  final String placeName;
  final String categoryTitle;
  final Color categoryColor;
  final IconData categoryIcon;

  const PlaceCommunityDetailScreen({
    super.key,
    required this.placeName,
    required this.categoryTitle,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  State<PlaceCommunityDetailScreen> createState() =>
      _PlaceCommunityDetailScreenState();
}

class _PlaceCommunityDetailScreenState
    extends State<PlaceCommunityDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _messages = [
    {
      'user': 'Marco Rossi',
      'text': 'Ciao a tutti! Locale fantastico e ottima compagnia.',
      'imageBytes': null,
      'time': '10:05',
    },
    {
      'user': 'Giulia Bianchi',
      'text': 'Consigliatissimo per chi ama questa passione!',
      'imageBytes': null,
      'time': '10:12',
    },
  ];

  Future<void> _sendMessage({Uint8List? imageBytes}) async {
    if (_messageController.text.trim().isEmpty && imageBytes == null) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add({
        'user': 'Tu',
        'text': _messageController.text.trim(),
        'imageBytes': imageBytes,
        'time': timeStr,
      });
    });

    _messageController.clear();

    // 🏆 Assegna +5 punti all'utente per aver inviato un messaggio nella Community
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'points': FieldValue.increment(5),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 30,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      _sendMessage(imageBytes: bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.placeName,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: widget.categoryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: widget.categoryColor.withOpacity(0.1),
            child: Row(
              children: [
                Icon(widget.categoryIcon, color: widget.categoryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chat Community - ${widget.categoryTitle}',
                    style: TextStyle(
                      color: widget.categoryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['user'] == 'Tu';

                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? widget.categoryColor : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['user'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.white70 : Colors.purple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (msg['imageBytes'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(msg['imageBytes']),
                            ),
                          ),
                        if (msg['text'].toString().isNotEmpty)
                          Text(
                            msg['text'],
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            msg['time'],
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white60 : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo, color: Colors.grey),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Scrivi un messaggio...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: widget.categoryColor),
                  onPressed: () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
