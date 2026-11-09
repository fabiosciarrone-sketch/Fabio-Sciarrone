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

  /// Codice breve (8 caratteri) da leggere a voce o digitare se la
  /// fotocamera non funziona.
  static String shortCodeFor(String couponId) {
    final clean = couponId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final tail =
        clean.length > 8 ? clean.substring(clean.length - 8) : clean;
    return tail.toUpperCase();
  }

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
        .where('shortCode', isEqualTo: shortCode.trim().toUpperCase())
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : q.docs.first.id;
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
