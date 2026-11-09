import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'venue_detail_screen.dart';

class VenuesScreen extends StatefulWidget {
  const VenuesScreen({super.key});

  @override
  State<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends State<VenuesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _venues = [];
  String _statusMessage = 'Ricerca locali vicini in corso...';

  @override
  void initState() {
    super.initState();
    _fetchNearbyVenues();
  }

  Future<void> _fetchNearbyVenues() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Rilevamento posizione GPS...';
    });

    try {
      // 1. Verifica i permessi e lo stato del GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _statusMessage =
              'I servizi di geolocalizzazione sono disabilitati sul dispositivo.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Permessi di localizzazione negati.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Permessi di localizzazione permanentemente negati.';
        });
        return;
      }

      // 2. Ottiene la posizione corrente
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _statusMessage = 'Connessione al server in corso...';
      });

      // 3. Chiamata alla Firebase Cloud Function
      final double lat = position.latitude;
      final double lng = position.longitude;

      final String url =
          "https://us-central1-SideBySide-bd245.cloudfunctions.net/getPlaces?"
          "lat=$lat"
          "&lng=$lng"
          "&type=gym|bar|store|restaurant";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List results = data['results'] ?? [];

        List<Map<String, dynamic>> loadedVenues =
            results.map<Map<String, dynamic>>((place) {
          return {
            'id': place['place_id'] ?? '',
            'name': place['name'] ?? 'Locale',
            'address': place['vicinity'] ?? 'Indirizzo non disponibile',
            'category': (place['types'] != null && place['types'].isNotEmpty)
                ? _formatCategory(place['types'][0])
                : 'Attività',
            'lat': place['geometry']['location']['lat'],
            'lng': place['geometry']['location']['lng'],
          };
        }).toList();

        setState(() {
          _venues = loadedVenues;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage =
              'Errore server [${response.statusCode}]: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Errore di rete/CORS: $e';
      });
    }
  }

  String _formatCategory(String type) {
    switch (type) {
      case 'gym':
        return 'Palestra 🏋️‍♂️️';
      case 'bar':
        return 'Bar / Pub 🍻';
      case 'store':
        return 'Negozio 🛍️';
      case 'restaurant':
        return 'Ristorante 🍽️';
      default:
        return 'Attività locale ✨';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Locali Vicini 📍',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchNearbyVenues,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.purple),
                  const SizedBox(height: 16),
                  Text(_statusMessage,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _venues.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront,
                            size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple),
                          onPressed: _fetchNearbyVenues,
                          child: const Text('Riprova',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _venues.length,
                  itemBuilder: (context, index) {
                    var venue = _venues[index];
                    String venueName = venue['name'];
                    String category = venue['category'];
                    String address = venue['address'];

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.purple.shade100,
                          child: const Icon(Icons.location_on,
                              color: Colors.purple, size: 28),
                        ),
                        title: Text(
                          venueName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(category,
                                style: const TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VenueDetailScreen(
                                venueId: venue['id'],
                                venueName: venueName,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
