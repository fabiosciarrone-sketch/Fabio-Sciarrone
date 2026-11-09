import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Importante per il QR code reale

class OffersListScreen extends StatefulWidget {
  const OffersListScreen({super.key});

  @override
  State<OffersListScreen> createState() => _OffersListScreenState();
}

class _OffersListScreenState extends State<OffersListScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _userCity = '';
  bool _isLoadingCity = true;

  @override
  void initState() {
    super.initState();
    _loadUserCity();
  }

  Future<void> _loadUserCity() async {
    if (currentUserId.isEmpty) {
      setState(() => _isLoadingCity = false);
      return;
    }
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _userCity =
              (doc.data()?['city'] ?? '').toString().trim().toLowerCase();
        });
      }
    } catch (e) {
      debugPrint("Errore caricamento città utente: $e");
    } finally {
      setState(() {
        _isLoadingCity = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCity) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Offerte e Promozioni Locali',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.amber.shade800,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Costruiamo la query applicando il filtro per città se l'utente l'ha impostata
    Query query = FirebaseFirestore.instance.collection('offers');
    if (_userCity.isNotEmpty) {
      query = query.where('city', isEqualTo: _userCity);
    }
    query = query.orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _userCity.isEmpty
              ? 'Offerte e Promozioni Locali (Tutte le città)'
              : 'Offerte a ${_userCity.toUpperCase()}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.amber.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  _userCity.isEmpty
                      ? 'Nessuna offerta attiva al momento.'
                      : 'Nessuna offerta attiva al momento per la città di ${_userCity.toUpperCase()}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final offers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index].data() as Map<String, dynamic>;
              final title = offer['title'] ?? 'Offerta';
              final description = offer['description'] ?? '';
              final businessName = offer['businessName'] ?? 'Negozio';
              final city = offer['city'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            OfferDetailScreen(offerData: offer),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                city.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.store,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 6),
                            Text(
                              businessName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class OfferDetailScreen extends StatelessWidget {
  final Map<String, dynamic> offerData;

  const OfferDetailScreen({super.key, required this.offerData});

  @override
  Widget build(BuildContext context) {
    final title = offerData['title'] ?? 'Offerta';
    final description = offerData['description'] ?? '';
    final businessName = offerData['businessName'] ?? 'Negozio';
    final city = offerData['city'] ?? '';

    // Dati reali codificati dentro il QR code (es. ID univoco della promozione)
    final qrData =
        "SIDEBYSIDE_COUPON:${offerData['title']}_${offerData['businessName']}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pass Sconto Reale',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.amber.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.store, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  businessName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.location_city, color: Colors.grey, size: 20),
                const SizedBox(width: 4),
                Text(
                  city.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 30),
            const Text(
              'Descrizione Promozione:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                  fontSize: 16, color: Colors.grey.shade800, height: 1.4),
            ),
            const SizedBox(height: 30),

            // Box del QR Code REALE
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade400, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner,
                          size: 28, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'QR Code di Sconto Ufficiale',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Fai scansionare questo QR code direttamente dal negoziante alla cassa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),

                  // QUI VIENE GENERATO IL QR CODE REALE SCANSIONABILE
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200.0,
                      gapless: true,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),

                  const SizedBox(height: 15),
                  Text(
                    'Codice: ${title.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Coupon validato con successo in cassa! 🎉'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: const Text('Simula Convalida Negoziante',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
