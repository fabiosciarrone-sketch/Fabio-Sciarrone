import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'coupon_service.dart';

/// Schermata del negoziante per convalidare i coupon dei clienti:
/// scansione del QR oppure inserimento del codice manuale.
class CouponScannerScreen extends StatefulWidget {
  const CouponScannerScreen({super.key});

  @override
  State<CouponScannerScreen> createState() => _CouponScannerScreenState();
}

class _CouponScannerScreenState extends State<CouponScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _codeController = TextEditingController();
  final String _businessId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final couponId = CouponService.parseQr(raw);
      if (couponId == null) {
        await _handle(null, invalidQr: true);
      } else {
        await _handle(couponId);
      }
      break;
    }
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 4 || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    String? couponId;
    try {
      couponId = await CouponService.findByShortCode(_businessId, code);
    } catch (e) {
      debugPrint('Errore ricerca codice: $e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (couponId == null) {
      await _showResult(
        icon: Icons.search_off,
        color: Colors.orange,
        title: 'Codice non trovato',
        message:
            'Nessun coupon con il codice $code per le offerte del tuo negozio.',
      );
      return;
    }
    await _handle(couponId);
    _codeController.clear();
  }

  Future<void> _handle(String? couponId, {bool invalidQr = false}) async {
    setState(() => _busy = true);
    try {
      await _controller.stop();
    } catch (_) {}

    if (invalidQr || couponId == null) {
      await _showResult(
        icon: Icons.qr_code_2,
        color: Colors.orange,
        title: 'QR non valido',
        message: 'Questo QR code non è un coupon SideBySide.',
      );
    } else {
      final result = await CouponService.redeem(couponId, _businessId);
      final offerTitle = (result.data?['offerTitle'] ?? '').toString();
      switch (result.status) {
        case RedeemStatus.ok:
          await _showResult(
            icon: Icons.check_circle,
            color: Colors.green,
            title: 'Coupon convalidato! ✅',
            message: offerTitle.isEmpty
                ? 'Applica lo sconto al cliente.'
                : 'Applica lo sconto: "$offerTitle".',
          );
          break;
        case RedeemStatus.alreadyUsed:
          await _showResult(
            icon: Icons.block,
            color: Colors.red,
            title: 'Coupon già utilizzato',
            message: 'Questo coupon è già stato convalidato in precedenza.',
          );
          break;
        case RedeemStatus.otherBusiness:
          await _showResult(
            icon: Icons.store_mall_directory,
            color: Colors.orange,
            title: 'Coupon di un altro negozio',
            message:
                'Puoi convalidare solo i coupon delle offerte pubblicate dal tuo negozio.',
          );
          break;
        case RedeemStatus.notFound:
          await _showResult(
            icon: Icons.search_off,
            color: Colors.orange,
            title: 'Coupon inesistente',
            message: 'Questo coupon non esiste o è stato rimosso.',
          );
          break;
        case RedeemStatus.error:
          await _showResult(
            icon: Icons.error_outline,
            color: Colors.red,
            title: 'Errore',
            message:
                'Impossibile convalidare il coupon. Controlla la connessione e riprova.',
          );
          break;
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);
    try {
      await _controller.start();
    } catch (e) {
      debugPrint('Riavvio fotocamera non riuscito: $e');
    }
  }

  Future<void> _showResult({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(icon, color: color, size: 56),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c),
            child: const Text('Scansiona un altro'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convalida coupon',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.amber.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) => Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: const Text(
                      'Fotocamera non disponibile.\nControlla i permessi oppure inserisci il codice manuale qui sotto.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.amber, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_busy)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Inquadra il QR del cliente oppure inserisci il codice manuale',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Es. A1B2C3D4',
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onSubmitted: (_) => _submitCode(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        onPressed: _busy ? null : _submitCode,
                        child: const Text('Convalida'),
                      ),
                    ],
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
