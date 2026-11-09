import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isUserPremium = false;
  bool _isCompanyPremium = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    if (currentUserId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _isUserPremium = doc.data()?['isUserPremium'] ?? false;
          _isCompanyPremium = doc.data()?['isCompanyPremium'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Errore caricamento abbonamenti: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _activateSubscription(String type, double price) async {
    if (currentUserId.isEmpty) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Conferma Abbonamento $type'),
        content: Text(
            'Vuoi attivare il piano $type al costo di ${price.toStringAsFixed(0)}€ al mese? (Simulazione pagamento)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Conferma', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      Map<String, dynamic> updateData = {};
      if (type == 'Utente') {
        updateData['isUserPremium'] = true;
        updateData['userPremiumSince'] = FieldValue.serverTimestamp();
        setState(() => _isUserPremium = true);
      } else {
        updateData['isCompanyPremium'] = true;
        updateData['companyPremiumSince'] = FieldValue.serverTimestamp();
        setState(() => _isCompanyPremium = true);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set(updateData, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Abbonamento $type attivato con successo! 🎉'),
          backgroundColor: Colors.purple,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Errore attivazione: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SideBySide Abbonamenti 🌟',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Scegli il piano ideale per te',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sblocca funzioni avanzate per utenti o promuovi la tua attività commerciale.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // CARD ABBONAMENTO UTENTE (5€ / mese)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                border: Border.all(
                  color: _isUserPremium ? Colors.green : Colors.purple.shade200,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.purple, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'Abbonamento Utente',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '5€ / mese',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Filtri avanzati nei locali e nelle vicinanze\n• Visibilità prioritaria e chat illimitate\n• Badge esclusivo profilo',
                    style: TextStyle(
                        fontSize: 13, color: Colors.black87, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isUserPremium ? Colors.green : Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isUserPremium
                          ? null
                          : () => _activateSubscription('Utente', 5.0),
                      child: Text(
                        _isUserPremium
                            ? 'Attivo (Piano Utente)'
                            : 'Attiva Abbonamento Utente (5€)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // CARD ABBONAMENTO AZIENDA (20€ / mese)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(
                  color:
                      _isCompanyPremium ? Colors.green : Colors.amber.shade300,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.business, color: Colors.orange, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'Abbonamento Azienda',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '20€ / mese',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Inserisci pubblicità e promozioni in evidenza\n• Promuovi il tuo locale nella community\n• Statistiche e visibilità avanzata',
                    style: TextStyle(
                        fontSize: 13, color: Colors.black87, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isCompanyPremium ? Colors.green : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isCompanyPremium
                          ? null
                          : () => _activateSubscription('Azienda', 20.0),
                      child: Text(
                        _isCompanyPremium
                            ? 'Attivo (Piano Azienda)'
                            : 'Attiva Abbonamento Azienda (20€)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
