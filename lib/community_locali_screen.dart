import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import 'community_service.dart';
import 'photo_utils.dart';

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
                            // Senza connessione mostra solo il colore
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: cat['color'] as Color),
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

// =============================================================================
// ELENCO STANZE DI UNA CATEGORIA
// =============================================================================
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

  @override
  void initState() {
    super.initState();
    _determinePositionInBackground();
  }

  Future<void> _determinePositionInBackground() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _userPosition = position);
    } catch (e) {
      debugPrint("Errore GPS: $e");
    }
  }

  void _showAddPlaceDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      // Non si chiude toccando fuori mentre la stanza viene salvata
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                maxLength: CommunityService.maxNameLength,
                decoration: const InputDecoration(
                  labelText: 'Nome Locale / Stanza (es. Up Level)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                maxLines: 2,
                maxLength: CommunityService.maxDescriptionLength,
                decoration: const InputDecoration(
                  labelText: 'Breve descrizione',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_userPosition == null)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Posizione non disponibile: la stanza verrà creata '
                    'senza distanza.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child:
                  const Text('Annulla', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.categoryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) return;

                      // Navigator e ScaffoldMessenger presi PRIMA delle
                      // operazioni asincrone: il dialog potrebbe chiudersi.
                      final navigator = Navigator.of(dialogContext);
                      final messenger = ScaffoldMessenger.of(context);
                      final placeName = nameController.text.trim();
                      setDialogState(() => saving = true);

                      try {
                        final placeId = await CommunityService.createPlace(
                          name: nameController.text,
                          description: descController.text,
                          category: widget.categoryTitle,
                          latitude: _userPosition?.latitude,
                          longitude: _userPosition?.longitude,
                        );

                        if (dialogContext.mounted) navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Stanza creata! 🏆'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        if (!mounted) return;
                        _openPlace(placeId, placeName);
                      } catch (e) {
                        setDialogState(() => saving = false);
                        messenger.showSnackBar(
                          SnackBar(
                              content: Text('Errore durante la creazione: $e')),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Crea', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameController.dispose();
      descController.dispose();
    });
  }

  String _calculateDistance(double? destLat, double? destLon) {
    if (_userPosition == null || destLat == null || destLon == null) {
      return 'Distanza non disponibile';
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

  void _openPlace(String placeId, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceCommunityDetailScreen(
          placeId: placeId,
          placeName: name,
          categoryTitle: widget.categoryTitle,
          categoryColor: widget.categoryColor,
          categoryIcon: widget.categoryIcon,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.categoryIcon,
                size: 64, color: widget.categoryColor.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'Ancora nessuna stanza in "${widget.categoryTitle}"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea la prima stanza e invita gli altri a unirsi!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: CommunityService.places
            .where('category', isEqualTo: widget.categoryTitle)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Impossibile caricare le stanze.\n'
                    '${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Le stanze più popolate in alto
          final docs = [...snapshot.data!.docs]..sort((a, b) =>
              CommunityService.asInt(b.data()['membersCount'])
                  .compareTo(CommunityService.asInt(a.data()['membersCount'])));

          if (docs.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final placeId = docs[index].id;
              final data = docs[index].data();
              final name =
                  (data['name'] ?? widget.categoryTitle).toString();
              final description =
                  (data['description'] ?? 'Punto di riferimento.').toString();
              final lat = CommunityService.asDouble(data['latitude']);
              final lon = CommunityService.asDouble(data['longitude']);
              final membersCount =
                  CommunityService.asInt(data['membersCount']);
              final distanceText = _calculateDistance(lat, lon);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: () => _openPlace(placeId, name),
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
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(distanceText,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person,
                                  size: 14, color: widget.categoryColor),
                              const SizedBox(width: 4),
                              Text(
                                membersCount == 1
                                    ? '1 partecipante'
                                    : '$membersCount partecipanti',
                                style: TextStyle(
                                    color: widget.categoryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: _JoinButton(
                    placeId: placeId,
                    color: widget.categoryColor,
                    onOpen: () => _openPlace(placeId, name),
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

/// Pulsante "Unisciti" / "Apri" che segue in tempo reale l'iscrizione.
class _JoinButton extends StatefulWidget {
  final String placeId;
  final Color color;
  final VoidCallback onOpen;

  const _JoinButton({
    required this.placeId,
    required this.color,
    required this.onOpen,
  });

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  bool _busy = false;
  late final Stream<bool> _memberStream =
      CommunityService.isMemberStream(widget.placeId);

  Future<void> _join() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await CommunityService.join(widget.placeId);
      widget.onOpen();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Impossibile unirsi alla stanza: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _memberStream,
      builder: (context, snapshot) {
        final isMember = snapshot.data ?? false;
        if (isMember) {
          return OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.color,
              side: BorderSide(color: widget.color),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: widget.onOpen,
            child: const Text('Apri'),
          );
        }
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _busy || !snapshot.hasData ? null : _join,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Unisciti', style: TextStyle(color: Colors.white)),
        );
      },
    );
  }
}

// =============================================================================
// CHAT DELLA STANZA
// =============================================================================
class PlaceCommunityDetailScreen extends StatefulWidget {
  final String placeId;
  final String placeName;
  final String categoryTitle;
  final Color categoryColor;
  final IconData categoryIcon;

  const PlaceCommunityDetailScreen({
    super.key,
    required this.placeId,
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

  late final Stream<bool> _memberStream =
      CommunityService.isMemberStream(widget.placeId);
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream =
      CommunityService.messagesStream(widget.placeId);
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _placeStream =
      CommunityService.places.doc(widget.placeId).snapshots();

  String _myName = 'Utente';
  Set<String> _blocked = {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    CommunityService.myDisplayName().then((n) {
      if (mounted) setState(() => _myName = n);
    });
    CommunityService.myBlockedUsers().then((b) {
      if (mounted) setState(() => _blocked = b);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _showSnack(String text, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  Future<void> _sendMessage({Uint8List? imageBytes}) async {
    final text = _messageController.text.trim();
    if ((text.isEmpty && imageBytes == null) || _sending) return;

    setState(() => _sending = true);
    try {
      await CommunityService.sendMessage(
        placeId: widget.placeId,
        senderName: _myName,
        text: text,
        imageBytes: imageBytes,
      );
      // I punti (+5, con tetto giornaliero) li assegna la Cloud Function
      if (imageBytes == null) _messageController.clear();
    } on CommunityException catch (e) {
      _showSnack(e.message, color: Colors.orange);
    } on FirebaseException catch (e) {
      _showSnack(
        e.code == 'permission-denied'
            ? 'Unisciti alla stanza per scrivere.'
            : 'Messaggio non inviato: ${e.message}',
        color: Colors.red,
      );
    } catch (e) {
      _showSnack('Messaggio non inviato: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 40,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      await _sendMessage(imageBytes: bytes);
    }
  }

  Future<void> _join() async {
    try {
      await CommunityService.join(widget.placeId);
      _showSnack('Ti sei unito alla stanza! 🎉', color: Colors.green);
    } catch (e) {
      _showSnack('Impossibile unirsi alla stanza: $e', color: Colors.red);
    }
  }

  Future<void> _leave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uscire dalla stanza?'),
        content: const Text(
            'Potrai ancora leggere i messaggi, ma non scrivere finché non ti '
            'unisci di nuovo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Esci', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await CommunityService.leave(widget.placeId);
      _showSnack('Sei uscito dalla stanza.');
    } catch (e) {
      _showSnack('Errore: $e', color: Colors.red);
    }
  }

  Future<void> _showMessageActions(
      String messageId, Map<String, dynamic> msg, bool isMine) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Elimina messaggio'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.red),
                title: const Text('Segnala messaggio'),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Annulla'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );

    if (action == 'delete') {
      try {
        await CommunityService.deleteMyMessage(widget.placeId, messageId);
      } catch (e) {
        _showSnack('Impossibile eliminare il messaggio: $e', color: Colors.red);
      }
    } else if (action == 'report') {
      await _reportMessage(messageId, msg);
    }
  }

  Future<void> _reportMessage(String messageId, Map<String, dynamic> msg) async {
    const reasons = [
      'Spam o pubblicità',
      'Offensivo o di odio',
      'Contenuto sessuale o inappropriato',
      'Molestie o minacce',
      'Altro',
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Perché segnali questo messaggio?'),
        children: [
          for (final r in reasons)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(r),
              ),
            ),
        ],
      ),
    );
    if (reason == null) return;

    final outcome = await CommunityService.reportMessage(
      placeId: widget.placeId,
      messageId: messageId,
      message: msg,
      reason: reason,
    );
    switch (outcome) {
      case ReportOutcome.sent:
        _showSnack('Grazie! La segnalazione è stata inviata.',
            color: Colors.green);
        break;
      case ReportOutcome.alreadyReported:
        _showSnack('Hai già segnalato questo messaggio.');
        break;
      case ReportOutcome.error:
        _showSnack('Segnalazione non inviata, riprova.', color: Colors.red);
        break;
    }
  }

  String _formatTime(dynamic ts) {
    final date = ts is Timestamp ? ts.toDate() : DateTime.now();
    final now = DateTime.now();
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    final sameDay = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    if (sameDay) return '$hh:$mm';
    final dd = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    return '$dd/$mo $hh:$mm';
  }

  Widget _buildMessage(String messageId, Map<String, dynamic> msg) {
    final myUid = CommunityService.myUid;
    final isMe = msg['senderId'] == myUid;
    final sender = isMe ? 'Tu' : (msg['senderName'] ?? 'Utente').toString();
    final text = (msg['text'] ?? '').toString();
    final image = (msg['imageBase64'] ?? '').toString();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(messageId, msg, isMe),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      sender,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white70 : Colors.purple,
                      ),
                    ),
                  ),
                  // Su iPhone/web il "tieni premuto" non è ovvio: icona menu
                  InkWell(
                    onTap: () => _showMessageActions(messageId, msg, isMe),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.more_horiz,
                          size: 16,
                          color: isMe ? Colors.white70 : Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (image.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PhotoUtils.image(
                      image,
                      fit: BoxFit.contain,
                      placeholder: const SizedBox(
                        height: 60,
                        child: Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                ),
              if (text.isNotEmpty)
                Text(
                  text,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  _formatTime(msg['timestamp']),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white60 : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Impossibile caricare i messaggi.\n'
                  '${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Nasconde i messaggi oscurati dalle segnalazioni e quelli degli
        // utenti bloccati
        final docs = snapshot.data!.docs.where((d) {
          final data = d.data();
          if (data['hidden'] == true) return false;
          return !_blocked.contains((data['senderId'] ?? '').toString());
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Nessun messaggio ancora.\nRompi il ghiaccio! 👋',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
          );
        }

        return ListView.builder(
          reverse: true, // i più recenti in basso
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) =>
              _buildMessage(docs[index].id, docs[index].data()),
        );
      },
    );
  }

  Widget _buildComposer(bool isMember) {
    if (!isMember) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.categoryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _join,
            icon: const Icon(Icons.group_add, color: Colors.white),
            label: const Text('Unisciti per scrivere',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo, color: Colors.grey),
              onPressed: _sending ? null : _pickImage,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLength: CommunityService.maxMessageLength,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Scrivi un messaggio...',
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            _sending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.send, color: widget.categoryColor),
                    onPressed: () => _sendMessage(),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _memberStream,
      builder: (context, memberSnap) {
        final isMember = memberSnap.data ?? false;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.placeName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: widget.categoryColor,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (isMember)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (v) {
                    if (v == 'leave') _leave();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'leave',
                      child: Text('Esci dalla stanza'),
                    ),
                  ],
                ),
            ],
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
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _placeStream,
                      builder: (context, snap) {
                        final count = CommunityService.asInt(
                            snap.data?.data()?['membersCount']);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person,
                                size: 16, color: widget.categoryColor),
                            const SizedBox(width: 4),
                            Text(
                              '$count',
                              style: TextStyle(
                                color: widget.categoryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildMessages()),
              _buildComposer(isMember),
            ],
          ),
        );
      },
    );
  }
}
