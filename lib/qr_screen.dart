import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Importa il pacchetto per generare il QR

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MobileScannerController cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _openUserChat(String scannedUserId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(scannedUserId)
          .get();
      if (!userDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utente non trovato nel database.')),
        );
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final name = userData['name'] ?? 'Utente';

      if (!mounted) return;

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final chatId = currentUserId.compareTo(scannedUserId) < 0
          ? '${currentUserId}_$scannedUserId'
          : '${scannedUserId}_$currentUserId';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(chatId: chatId, receiverName: name),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la scansione: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Codice QR & Scanner'),
        backgroundColor: Colors.teal,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scannerizza'),
            Tab(icon: Icon(Icons.qr_code), text: 'Il mio QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Scheda 1: Scanner (per inquadrare gli altri)
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  final scannedUserId = barcode.rawValue!;
                  cameraController.stop();
                  _openUserChat(scannedUserId);
                  break;
                }
              }
            },
          ),

          // Scheda 2: Il tuo QR Code personale (da far scansionare agli altri)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Mostra questo codice per farti aggiungere',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.3), //
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: currentUserId.isNotEmpty
                        ? QrImageView(
                            data: currentUserId,
                            version: QrVersions.auto,
                            size: 220.0,
                            backgroundColor: Colors.white,
                          )
                        : const CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Gli altri utenti potranno inquadrare questo codice con la loro app SideBySide per iniziare subito a chattare con te!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
