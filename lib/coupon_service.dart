import 'package:cloud_firestore/cloud_firestore.dart';

/// Gestione dei coupon delle offerte.
///
/// Ogni utente ha UN coupon personale per ogni offerta, salvato in
/// `coupons/{offerId}_{userId}`. Il QR code contiene `SBS-COUPON:{couponId}`.
/// Solo il negoziante che ha pubblicato l'offerta può convalidarlo, e
/// una sola volta (stato 'active' → 'redeemed').
class CouponService {
  CouponService._();

  static const String qrPrefix = 'SBS-COUPON:';

  static final CollectionReference<Map<String, dynamic>> _coupons =
      FirebaseFirestore.instance.collection('coupons');

  static String couponId(String offerId, String userId) =>
      '${offerId}_$userId';

  /// Alfabeto del codice breve: niente 0/O e 1/I, che si confondono
  /// quando il codice viene letto a voce o digitato a mano.
  static const String _shortCodeAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  /// Hash FNV-1a a 32 bit. Scritto in modo da dare lo stesso risultato
  /// su Android/iOS e sul web (dove gli interi sono numeri JavaScript).
  static int _fnv1a32(String input, int seed) {
    var h = seed & 0xFFFFFFFF;
    for (final c in input.codeUnits) {
      h = (h ^ c) & 0xFFFFFFFF;
      // h * 16777619 (primo FNV) = h * 403 + h * 2^24, modulo 2^32
      h = (h * 403 + ((h << 24) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    }
    return h;
  }

  /// Codice breve (8 caratteri) da leggere a voce o digitare se la
  /// fotocamera non funziona.
  ///
  /// È calcolato da un hash dell'ID COMPLETO del coupon (offerta + utente),
  /// così ogni offerta ha un codice diverso anche per lo stesso cliente.
  /// (Prima si usavano gli ultimi 8 caratteri dell'ID, cioè solo la parte
  /// dell'utente: lo stesso cliente aveva lo stesso codice su tutte le
  /// offerte del negozio.)
  static String shortCodeFor(String couponId) {
    final h1 = _fnv1a32(couponId, 0x811C9DC5);
    final h2 = _fnv1a32(couponId, 0x5BD1E995);
    final buf = StringBuffer();
    for (var i = 0; i < 4; i++) {
      buf.write(_shortCodeAlphabet[(h1 >> (5 * i)) & 31]);
    }
    for (var i = 0; i < 4; i++) {
      buf.write(_shortCodeAlphabet[(h2 >> (5 * i)) & 31]);
    }
    return buf.toString();
  }

  /// Pulisce il codice digitato dal negoziante (spazi, trattini, minuscole).
  static String normalizeShortCode(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String qrDataFor(String couponId) => '$qrPrefix$couponId';

  /// Restituisce il coupon dell'utente per questa offerta, creandolo se
  /// non esiste ancora.
  static Future<DocumentReference<Map<String, dynamic>>> getOrCreate({
    required String offerId,
    required String userId,
    required Map<String, dynamic> offerData,
  }) async {
    final id = couponId(offerId, userId);
    final ref = _coupons.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'offerId': offerId,
        'userId': userId,
        'businessId': offerData['businessId'] ?? '',
        'offerTitle': offerData['title'] ?? '',
        'businessName': offerData['businessName'] ?? '',
        'shortCode': shortCodeFor(id),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return ref;
  }

  /// Estrae l'ID coupon dal testo letto nel QR. Null se non è un coupon.
  static String? parseQr(String raw) {
    final value = raw.trim();
    if (!value.startsWith(qrPrefix)) return null;
    final id = value.substring(qrPrefix.length).trim();
    if (id.isEmpty || id.contains('/')) return null;
    return id;
  }

  /// Cerca un coupon del negozio tramite il codice breve.
  static Future<String?> findByShortCode(
      String businessId, String shortCode) async {
    final q = await _coupons
        .where('businessId', isEqualTo: businessId)
        .where('shortCode', isEqualTo: normalizeShortCode(shortCode))
        .limit(2)
        .get();
    // Se (molto raramente) due coupon dello stesso negozio hanno lo stesso
    // codice, non indoviniamo: meglio chiedere di scansionare il QR.
    return q.docs.length == 1 ? q.docs.first.id : null;
  }

  /// Convalida il coupon per il negozio [businessId].
  static Future<RedeemResult> redeem(
      String couponId, String businessId) async {
    final ref = _coupons.doc(couponId);
    try {
      return await FirebaseFirestore.instance
          .runTransaction<RedeemResult>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          return const RedeemResult(RedeemStatus.notFound);
        }
        final data = snap.data()!;
        if (data['businessId'] != businessId) {
          return RedeemResult(RedeemStatus.otherBusiness, data: data);
        }
        if (data['status'] == 'redeemed') {
          return RedeemResult(RedeemStatus.alreadyUsed, data: data);
        }
        tx.update(ref, {
          'status': 'redeemed',
          'redeemedAt': FieldValue.serverTimestamp(),
        });
        return RedeemResult(RedeemStatus.ok, data: data);
      });
    } on FirebaseException catch (e) {
      // Le regole negano la lettura se il coupon non è di questo negozio
      if (e.code == 'permission-denied') {
        return const RedeemResult(RedeemStatus.otherBusiness);
      }
      return RedeemResult(RedeemStatus.error, message: e.message);
    } catch (e) {
      return RedeemResult(RedeemStatus.error, message: e.toString());
    }
  }
}

enum RedeemStatus { ok, alreadyUsed, otherBusiness, notFound, error }

class RedeemResult {
  final RedeemStatus status;
  final Map<String, dynamic>? data;
  final String? message;
  const RedeemResult(this.status, {this.data, this.message});
}
