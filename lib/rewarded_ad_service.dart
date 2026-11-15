import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ticket_ad_service.dart';

/// Esito della richiesta di un video a premi.
enum RewardedAdResult {
  /// L'utente ha guardato il video fino in fondo: premio assegnato.
  earned,

  /// Il video e' partito ma l'utente lo ha chiuso prima della fine.
  closedEarly,

  /// Nessun video disponibile (non caricato, consenso mancante, errore).
  unavailable,
}

/// Gestisce il video pubblicitario a premi (RewardedAd) del Profilo.
///
/// Uso:
///   RewardedAdService.preload();   // quando si apre la schermata
///   final esito = await RewardedAdService.show(
///     onUserEarnedReward: () { ...accredita il premio... },
///   );
class RewardedAdService {
  RewardedAdService._();

  // ATTENZIONE: questi sono gli ID di TEST ufficiali di Google.
  // Prima di pubblicare l'app sostituiscili con gli ID delle tue unita'
  // pubblicitarie "Con premio" create su https://admob.google.com
  static const String _androidAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  /// Tempo massimo di attesa per il caricamento del video.
  static const Duration _loadTimeout = Duration(seconds: 15);

  static RewardedAd? _ad;
  static Completer<RewardedAd?>? _loading;
  static bool _isShowing = false;

  static String get _adUnitId => defaultTargetPlatform == TargetPlatform.iOS
      ? _iosAdUnitId
      : _androidAdUnitId;

  /// Carica in anticipo il video, cosi' e' pronto quando l'utente tocca
  /// il pulsante.
  static Future<void> preload() async {
    try {
      if (!await TicketAdService.ensureAdsStarted()) return;
      await _load();
    } catch (e) {
      debugPrint('Errore precaricamento video a premi: $e');
    }
  }

  static Future<RewardedAd?> _load() {
    final ready = _ad;
    if (ready != null) return Future.value(ready);

    final pending = _loading;
    if (pending != null) return pending.future;

    final completer = Completer<RewardedAd?>();
    _loading = completer;

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = null;
          completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _loading = null;
          debugPrint('Video a premi non caricato: ${error.message}');
          completer.complete(null);
        },
      ),
    );

    return completer.future;
  }

  /// Mostra il video a tutto schermo e termina solo quando viene chiuso.
  ///
  /// [onUserEarnedReward] viene chiamata SOLO se l'utente ha completato la
  /// visione: e' l'unico punto in cui va accreditato il premio.
  static Future<RewardedAdResult> show({
    required VoidCallback onUserEarnedReward,
  }) async {
    if (_isShowing) return RewardedAdResult.unavailable;
    _isShowing = true;

    try {
      if (!await TicketAdService.ensureAdsStarted()) {
        return RewardedAdResult.unavailable;
      }

      final ad = await _load().timeout(_loadTimeout, onTimeout: () => null);
      if (ad == null) return RewardedAdResult.unavailable;

      // Ogni RewardedAd puo' essere mostrato una sola volta.
      _ad = null;

      var earned = false;
      var failed = false;
      final closed = Completer<void>();
      void finish() {
        if (!closed.isCompleted) closed.complete();
      }

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          finish();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('Video a premi non mostrato: ${error.message}');
          failed = true;
          ad.dispose();
          finish();
        },
      );

      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earned = true;
          onUserEarnedReward();
        },
      );
      await closed.future;

      if (earned) return RewardedAdResult.earned;
      return failed
          ? RewardedAdResult.unavailable
          : RewardedAdResult.closedEarly;
    } catch (e) {
      debugPrint('Errore durante il video a premi: $e');
      return RewardedAdResult.unavailable;
    } finally {
      _isShowing = false;
      // Prepara subito il video successivo.
      unawaited(preload());
    }
  }
}
