import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _offerTitleController = TextEditingController();
  final TextEditingController _offerDescController = TextEditingController();

  String _selectedCategory = 'Bar';
  final List<String> _categories = ['Bar', 'Palestra', 'Ristorante', 'Altro'];

  bool _isPremium = false;
  bool _isLoading = true;
  int _monthlyPromosCount = 0;
  String _lastPromoMonth = '';

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  Future<void> _loadBusinessData() async {
    if (currentUserId.isEmpty) return;
    try {
      var doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(currentUserId)
          .get();
      if (doc.exists && doc.data() != null) {
        var data = doc.data()!;
        final now = DateTime.now();
        final currentMonthKey = "${now.year}-${now.month}";

        // Controllo azzeramento mese se è cambiato il mese rispetto all'ultimo post
        int promosCount = data['monthlyPromosCount'] ?? 0;
        String lastMonth = data['lastPromoMonth'] ?? '';
        if (lastMonth != currentMonthKey) {
          promosCount = 0;
        }

        setState(() {
          _businessNameController.text = data['businessName'] ?? '';
          _cityController.text = data['city'] ?? '';
          _selectedCategory = data['category'] ?? 'Bar';
          _isPremium = data['isBusinessPremium'] ?? false;
          _monthlyPromosCount = promosCount;
          _lastPromoMonth = lastMonth;
        });
      }
    } catch (e) {
      debugPrint("Errore caricamento dati business: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveBusinessProfile() async {
    if (currentUserId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(currentUserId)
          .set({
        'userId': currentUserId,
        'businessName': _businessNameController.text.trim(),
        'city': _cityController.text.trim().toLowerCase(),
        'category': _selectedCategory,
        'isBusinessPremium': _isPremium,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profilo Aziendale salvato con successo! ✅'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint("Errore salvataggio business: $e");
    }
  }

  Future<void> _activatePremium() async {
    if (currentUserId.isEmpty) return;
    try {
      setState(() {
        _isPremium = true;
      });
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(currentUserId)
          .set({
        'isBusinessPremium': true,
        'premiumActivatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pass Business Premium attivato con successo! 🌟'),
            backgroundColor: Colors.amber),
      );
    } catch (e) {
      debugPrint("Errore attivazione premium: $e");
    }
  }

  // Simula o avvia il pagamento di 5€ per la singola inserzione
  Future<bool> _avviaPagamentoStripeInserzioneSingola() async {
    bool pagatoConSuccesso = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Pagamento Inserzione (5,00 €)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isPremium
                ? 'Hai esaurito le 5 inserzioni mensili incluse nel Pass Premium.'
                : 'Non hai un Pass Premium attivo.'),
            const SizedBox(height: 8),
            const Text(
                'Per pubblicare questa promozione è richiesto il pagamento di 5,00 € via Stripe.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              pagatoConSuccesso = true;
              Navigator.pop(context);
            },
            child: const Text('Paga 5,00 € (Stripe)',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return pagatoConSuccesso;
  }

  Future<void> _publishOffer() async {
    if (_offerTitleController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Inserisci titolo offerta e città valida!'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final now = DateTime.now();
    final currentMonthKey = "${now.year}-${now.month}";

    int attualiInserzioniMese = _monthlyPromosCount;
    if (_lastPromoMonth != currentMonthKey) {
      attualiInserzioniMese = 0;
    }

    // 🟡 CONTROLLO REGOLA PUBBLICAZIONE:
    // Se è premium E ha ancora inserzioni gratis (< 5), pubblica subito gratis.
    // Altrimenti richiede il pagamento di 5€.
    bool puoPubblicareGratis = _isPremium && attualiInserzioniMese < 5;

    if (!puoPubblicareGratis) {
      bool esitoPagamento = await _avviaPagamentoStripeInserzioneSingola();
      if (!esitoPagamento) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Pagamento non completato. Promozione non pubblicata.'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    try {
      await FirebaseFirestore.instance.collection('offers').add({
        'businessId': currentUserId,
        'businessName': _businessNameController.text.trim(),
        'title': _offerTitleController.text.trim(),
        'description': _offerDescController.text.trim(),
        'city': _cityController.text.trim().toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Aggiorna contatore del mese corrente su Firestore
      int nuovoConteggio = attualiInserzioniMese + 1;
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(currentUserId)
          .set({
        'monthlyPromosCount': nuovoConteggio,
        'lastPromoMonth': currentMonthKey,
      }, SetOptions(merge: true));

      setState(() {
        _monthlyPromosCount = nuovoConteggio;
        _lastPromoMonth = currentMonthKey;
      });

      _offerTitleController.clear();
      _offerDescController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(puoPubblicareGratis
                ? 'Promozione pubblicata gratis! (${5 - nuovoConteggio} rimanenti questo mese) 🚀'
                : 'Promozione pubblicata con successo (Pagato 5€)! 🚀'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint("Errore pubblicazione offerta: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final now = DateTime.now();
    final currentMonthKey = "${now.year}-${now.month}";
    int conteggioMostrato =
        (_lastPromoMonth == currentMonthKey) ? _monthlyPromosCount : 0;
    int promozioniRimanenti = 5 - conteggioMostrato;
    if (promozioniRimanenti < 0) promozioniRimanenti = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Area Business & Promo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gestisci Profilo Attività',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _businessNameController,
              decoration: const InputDecoration(
                labelText:
                    'Nome Attività (es. Palestra FitClub / Bar Centrale)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'Città (es. milano, roma)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _saveBusinessProfile,
                child: const Text('Salva Profilo Attività',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
            const Divider(height: 40, thickness: 2),

            // Sezione Pass Business Premium
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.workspace_premium,
                          color: Colors.amber, size: 28),
                      SizedBox(width: 8),
                      Text('Pass Business Premium',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isPremium
                        ? 'Stato: Attivo 🌟 (Hai 5 promozioni gratis al mese | Rimanenti questo mese: $promozioniRimanenti)'
                        : 'Stato: Non attivo (Senza Pass ogni promo costa 5€)',
                    style: TextStyle(
                        color: _isPremium
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cosa include il pass:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text('🚀 5 Inserzioni Promo gratis incluse al mese'),
                  const Text(
                      '⭐ Vetrina in Evidenza nella Home e nella Community'),
                  const Text(
                      '🎟️ Gestione Coupon e Offerte Sconto tracciabili'),
                  const SizedBox(height: 16),
                  if (!_isPremium)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade900,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _activatePremium,
                        child: const Text(
                            'Attiva Pass Business Premium (Simula Pagamento)'),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 40, thickness: 2),

            // Sezione Pubblica Promozione
            const Text('Pubblica Promozione Locale',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _offerTitleController,
              decoration: const InputDecoration(
                labelText:
                    'Titolo Promozione (es. Sconto 20% su tutti i cocktail)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _offerDescController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descrizione / Dettagli offerta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _publishOffer,
                child: const Text('Pubblica Promozione 📢',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
