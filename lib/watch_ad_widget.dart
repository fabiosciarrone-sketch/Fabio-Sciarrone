import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WatchAdWidget extends StatefulWidget {
  final VoidCallback? onRewardEarned;
  const WatchAdWidget({super.key, this.onRewardEarned});

  @override
  State<WatchAdWidget> createState() => _WatchAdWidgetState();
}

class _WatchAdWidgetState extends State<WatchAdWidget> {
  bool _isLoading = false;

  Future<void> _showRewardedAd() async {
    setState(() {
      _isLoading = true;
    });

    // Simula il caricamento dell'annuncio video (2 secondi)
    await Future.delayed(const Duration(seconds: 2));

    // Aggiunge 5 cuoricini all'utente corrente su Firestore
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'hearts': FieldValue.increment(5),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Errore aggiornamento cuoricini: $e");
      }
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // Notifica la schermata di ricaricare i dati se necessario
    if (widget.onRewardEarned != null) {
      widget.onRewardEarned!();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❤️ Ottimo! Hai guadagnato 5 cuoricini extra!'),
        backgroundColor: Colors.pink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: _isLoading ? null : _showRewardedAd,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.video_library),
      label: Text(
        _isLoading ? 'Caricamento annuncio...' : 'Guarda video (+5 Cuoricini)',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
