import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'coupon_service.dart';

class OffersListScreen extends StatefulWidget {
  const OffersListScreen({super.key});

  @override
  State<OffersListScreen> createState() => _OffersListScreenState();
}

class _OffersListScreenState extends State<OffersListScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _userCity = '';
  bool _isLoadingCity = true;
  bool _showAllCities = false;

  @override
  void initState() {
    super.initState();
    _loadUserCity();
  }

  Future<void> _loadUserCity() async {
    if (currentUserId.isEmpty) {
      if (mounted) setState(() => _isLoadingCity = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (mounted && doc.exists && doc.data() != null) {
        setState(() {
          _userCity =
              (doc.data()?['city'] ?? '').toString().trim().toLowerCase();
        });
      }
    } catch (e) {
      debugPrint("Errore caricamento città utente: $e");
    } finally {
      if (mounted) setState(() => _isLoadingCity = false);
    }
  }

  /// Ordina dalla più recente. Fatto qui (e non con orderBy su Firestore)
  /// così il filtro per città non richiede un indice composto.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortByDate(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final list = [...docs];
    list.sort((a, b) {
      final ta = a.data()['createdAt'];
      final tb = b.data()['createdAt'];
      final da = ta is Timestamp ? ta.toDate() : DateTime.now();
      final db = tb is Timestamp ? tb.toDate() : DateTime.now();
      return db.compareTo(da);
    });
    return list;
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

    final bool filterByCity = _userCity.isNotEmpty && !_showAllCities;

    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('offers');
    if (filterByCity) {
      query = query.where('city', isEqualTo: _userCity);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          filterByCity
              ? 'Offerte a ${_userCity.toUpperCase()}'
              : 'Offerte e Promozioni (Tutte le città)',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.amber.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_userCity.isNotEmpty)
            IconButton(
              tooltip: _showAllCities
                  ? 'Solo la mia città'
                  : 'Mostra tutte le città',
              icon: Icon(_showAllCities ? Icons.location_on : Icons.public),
              onPressed: () =>
                  setState(() => _showAllCities = !_showAllCities),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Errore caricamento offerte: ${snapshot.error}');
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Impossibile caricare le offerte. Controlla la connessione e riprova.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filterByCity
                          ? 'Nessuna offerta attiva al momento per la città di ${_userCity.toUpperCase()}.'
                          : 'Nessuna offerta attiva al momento.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    if (filterByCity) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showAllCities = true),
                        icon: const Icon(Icons.public),
                        label: const Text('Vedi le offerte di tutte le città'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          final offers = _sortByDate(snapshot.data!.docs);

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offerId = offers[index].id;
              final offer = offers[index].data();
              final title = (offer['title'] ?? 'Offerta').toString();
              final description = (offer['description'] ?? '').toString();
              final businessName =
                  (offer['businessName'] ?? '').toString().trim().isEmpty
                      ? 'Negozio'
                      : offer['businessName'].toString();
              final city = (offer['city'] ?? '').toString();

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
                        builder: (context) => OfferDetailScreen(
                            offerId: offerId, offerData: offer),
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
                            if (city.isNotEmpty)
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
                        if (description.isNotEmpty)
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
                            Expanded(
                              child: Text(
                                businessName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            const Icon(Icons.qr_code,
                                size: 18, color: Colors.amber),
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

/// Dettaglio offerta con il coupon personale (QR code a uso singolo).
class OfferDetailScreen extends StatefulWidget {
  final String offerId;
  final Map<String, dynamic> offerData;

  const OfferDetailScreen(
      {super.key, required this.offerId, required this.offerData});

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  Future<DocumentReference<Map<String, dynamic>>>? _couponFuture;

  bool get _isOwnOffer => widget.offerData['businessId'] == _uid;

  @override
  void initState() {
    super.initState();
    _prepareCoupon();
  }

  void _prepareCoupon() {
    if (_uid.isEmpty || _isOwnOffer) return;
    setState(() {
      _couponFuture = CouponService.getOrCreate(
        offerId: widget.offerId,
        userId: _uid,
        offerData: widget.offerData,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.offerData['title'] ?? 'Offerta').toString();
    final description = (widget.offerData['description'] ?? '').toString();
    final businessName =
        (widget.offerData['businessName'] ?? '').toString().trim().isEmpty
            ? 'Negozio'
            : widget.offerData['businessName'].toString();
    final city = (widget.offerData['city'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pass Sconto', style: TextStyle(color: Colors.white)),
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
            Wrap(
              spacing: 16,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                  ],
                ),
                if (city.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_city,
                          color: Colors.grey, size: 20),
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
              ],
            ),
            const Divider(height: 30),
            const Text(
              'Descrizione Promozione:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description.isEmpty ? 'Nessuna descrizione.' : description,
              style: TextStyle(
                  fontSize: 16, color: Colors.grey.shade800, height: 1.4),
            ),
            const SizedBox(height: 30),
            _buildCouponBox(),
          ],
        ),
      ),
    );
  }

  Widget _boxFrame({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber.shade400, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _buildCouponBox() {
    if (_uid.isEmpty) {
      return _boxFrame(
        child: const Text('Accedi per ottenere il tuo coupon.',
            textAlign: TextAlign.center),
      );
    }

    if (_isOwnOffer) {
      return _boxFrame(
        child: const Column(
          children: [
            Icon(Icons.storefront, size: 40, color: Colors.amber),
            SizedBox(height: 10),
            Text(
              'Questa è una tua offerta.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'I clienti ricevono qui il loro QR personale. Per convalidarlo usa "Scansiona coupon cliente" nell\'Area Business.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<DocumentReference<Map<String, dynamic>>>(
      future: _couponFuture,
      builder: (context, refSnap) {
        if (refSnap.hasError) {
          debugPrint('Errore creazione coupon: ${refSnap.error}');
          return _boxFrame(
            child: Column(
              children: [
                const Text('Impossibile generare il coupon in questo momento.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _prepareCoupon,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          );
        }
        if (!refSnap.hasData) {
          return _boxFrame(
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: refSnap.data!.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();
            if (data == null) {
              return _boxFrame(
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            final couponId = refSnap.data!.id;
            final bool redeemed = data['status'] == 'redeemed';
            final shortCode =
                (data['shortCode'] ?? CouponService.shortCodeFor(couponId))
                    .toString();

            return _boxFrame(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          redeemed
                              ? Icons.check_circle
                              : Icons.qr_code_scanner,
                          size: 28,
                          color: redeemed ? Colors.green : Colors.amber),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          redeemed
                              ? 'Coupon già utilizzato'
                              : 'Il tuo coupon personale',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    redeemed
                        ? 'Questo sconto è stato convalidato dal negoziante. Grazie!'
                        : 'Mostra questo QR code alla cassa: il negoziante lo scansiona dalla sua app per convalidare lo sconto. Vale una sola volta.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  Opacity(
                    opacity: redeemed ? 0.25 : 1,
                    child: Container(
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
                        data: CouponService.qrDataFor(couponId),
                        version: QrVersions.auto,
                        size: 200.0,
                        gapless: true,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text('Codice manuale',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                  SelectableText(
                    shortCode,
                    style: TextStyle(
                      fontSize: 22,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                      color: redeemed ? Colors.grey : Colors.black87,
                      decoration:
                          redeemed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
