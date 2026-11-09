import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'models/place_model.dart';
import 'services/places_service.dart';
import 'community_locali_screen.dart'; // <--- Import della schermata community (verifica il percorso se si trova in un'altra cartella)

class AroundMeScreen extends StatefulWidget {
  const AroundMeScreen({super.key});

  @override
  State<AroundMeScreen> createState() => _AroundMeScreenState();
}

class _AroundMeScreenState extends State<AroundMeScreen> {
  bool _isLoadingPlaces = false;
  Position? _currentPosition;
  String _errorMessage = '';
  List<PlaceModel> _places = [];
  final PlacesService _placesService = PlacesService();

  @override
  void initState() {
    super.initState();
    // Avvio immediato non bloccante
    _getRealLocationInBackground();
  }

  Future<void> _getRealLocationInBackground() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _errorMessage = 'I servizi di geolocalizzazione sono disabilitati.';
          });
        }
        _fetchNearbyPlaces(
            37.5079, 15.0830); // Coordinate di fallback (es. Catania)
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _errorMessage =
                  'I permessi di geolocalizzazione sono stati negati.';
            });
          }
          _fetchNearbyPlaces(37.5079, 15.0830);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'I permessi di geolocalizzazione sono permanentemente negati.';
          });
        }
        _fetchNearbyPlaces(37.5079, 15.0830);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }

      _fetchNearbyPlaces(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore GPS: $e';
        });
      }
      _fetchNearbyPlaces(37.5079, 15.0830);
    }
  }

  Future<void> _fetchNearbyPlaces(double lat, double lng) async {
    if (mounted) {
      setState(() {
        _isLoadingPlaces = true;
      });
    }

    try {
      List<PlaceModel> fetchedPlaces =
          await _placesService.fetchNearbyPlaces(lat, lng);
      if (mounted) {
        setState(() {
          _places = fetchedPlaces;
          _isLoadingPlaces = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPlaces = false;
          _errorMessage = 'Errore caricamento locali: $e';
        });
      }
    }
  }

  void _askForAdvice(PlaceModel place) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                place.name,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vuoi chiedere consigli o opinioni alla community su questo locale?',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.purple, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      place.address,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              // Prendiamo Navigator e ScaffoldMessenger PRIMA di chiudere
              // il dialog: dopo la chiusura il suo context non è più valido.
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              navigator.pop(); // Chiude il dialog

              // Reindirizza l'utente alla schermata della community
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => const CommunityLocaliScreen(),
                ),
              );

              // SnackBar in basso con la scritta richiesta
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Seleziona la categoria e crea la tua stanza per ${place.name} per avere consigli!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.purple,
                ),
              );
            },
            child: const Text('Chiedi consigli',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Funzione che gestisce categorie e dati reali di affluenza
  Widget _buildCategoryCrowdBadge(PlaceModel place) {
    final int count = place.activeUsersCount ?? 0;
    final String category = place.category.toLowerCase();

    String text;
    Color color;
    IconData icon;

    // Distinzione basata sulla categoria reale (es. Palestra vs Ristorante vs Movida)
    if (category.contains('palestra') || category.contains('gym')) {
      if (count > 10) {
        text = '💪 Allenamento intenso ($count)';
        color = Colors.blue;
      } else {
        text = '🏋️ Area fitness tranquilla ($count)';
        color = Colors.blueGrey;
      }
      icon = Icons.fitness_center;
    } else if (category.contains('ristorante') ||
        category.contains('food') ||
        category.contains('pizzeria')) {
      if (count > 10) {
        text = '🍽️ Ristorante affollato ($count)';
        color = Colors.green;
      } else {
        text = '✨ Posti disponibili ($count)';
        color = Colors.teal;
      }
      icon = Icons.restaurant;
    } else {
      // Categoria locale serale / movida generale
      if (count > 15) {
        text = '🔥 Alta Movida ($count persone)';
        color = Colors.orange;
        icon = Icons.local_fire_department;
      } else if (count > 5) {
        text = '⚡ Movida moderata ($count)';
        color = Colors.amber;
        icon = Icons.bolt;
      } else {
        text = '🌱 Atmosfera tranquilla ($count)';
        color = Colors.grey;
        icon = Icons.spa;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SideBySide - Locali Vicini (GPS)',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getRealLocationInBackground,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.purple.shade50,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  _currentPosition != null
                      ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)} | Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}'
                      : 'Ricerca posizione GPS in corso...',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingPlaces
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.purple),
                        SizedBox(height: 12),
                        Text('Cerco locali nelle vicinanze...'),
                      ],
                    ),
                  )
                : _places.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage.isNotEmpty
                                ? _errorMessage
                                : 'Nessun locale trovato nelle vicinanze.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _places.length,
                        itemBuilder: (context, index) {
                          final place = _places[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.purple.shade100,
                                child: const Icon(Icons.store,
                                    color: Colors.purple),
                              ),
                              title: Text(
                                place.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    place.category,
                                    style: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(place.address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),

                                  // --- BADGE DINAMICO REALE PER CATEGORIA ---
                                  const SizedBox(height: 6),
                                  _buildCategoryCrowdBadge(place),
                                  // ------------------------------------------

                                  if (place.distance != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Distanza: ${place.distance!.toStringAsFixed(0)} metri',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade50,
                                  foregroundColor: Colors.purple,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline,
                                    size: 16),
                                label: const Text('Consigli',
                                    style: TextStyle(fontSize: 12)),
                                onPressed: () => _askForAdvice(place),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
