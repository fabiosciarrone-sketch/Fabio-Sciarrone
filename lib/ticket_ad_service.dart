import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Gestisce:
///  1. il messaggio di consenso privacy GDPR (Google User Messaging Platform);
///  2. l'annuncio a tutto schermo (interstitial) mostrato quando l'utente
///     tocca "Acquista" su un evento, prima di aprire il sito dei biglietti.
///
/// Uso:
///   TicketAdService.initialize();               // una volta, in main.dart
///   await TicketAdService.showBeforeLeaving();  // prima di launchUrl
class TicketAdService {
  TicketAdService._();

  // ATTENZIONE: questi sono gli ID di TEST ufficiali di Google.
  // Prima di pubblicare l'app sostituiscili con gli ID delle tue unita'
  // pubblicitarie "Interstitial" create su https://admob.google.com
  static const String _androidAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosAdUnitId = 'ca-app-pub-3940256099942544/4411468910';

  /// Tempo minimo tra un annuncio e il successivo.
  /// Le regole AdMob vietano di mostrare un interstitial a ogni clic:
  /// tieni un intervallo, altrimenti rischi la sospensione degli annunci.
  static const Duration minInterval = Duration(minutes: 2);

  static InterstitialAd? _ad;
  static bool _consentFlowStarted = false;
  static bool _adsStarting = false;
  static bool _initialized = false;
  static bool _isLoading = false;
  static bool _isShowing = false;
  static DateTime? _lastShownAt;

  static bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get _adUnitId => defaultTargetPlatform == TargetPlatform.iOS
      ? _iosAdUnitId
      : _androidAdUnitId;

  /// Da chiamare una volta all'avvio dell'app (in main.dart).
  ///
  /// Chiede a Google lo stato del consenso, mostra il messaggio GDPR se
  /// serve (utenti in UE/Regno Unito) e solo dopo avvia gli annunci.
  static Future<void> initialize() async {
    if (!_isSupported || _consentFlowStarted) return;
    _consentFlowStarted = true;

    try {
      final params = ConsentRequestParameters();

      // Va richiesto a ogni avvio dell'app.
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          // Mostra il modulo di consenso solo se e' necessario.
          ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              debugPrint(
                  'Consenso non raccolto: ${formError.errorCode} ${formError.message}');
            }
            _startAdsIfAllowed();
          });
        },
        (FormError error) {
          debugPrint(
              'Errore aggiornamento consenso: ${error.errorCode} ${error.message}');
          _startAdsIfAllowed();
        },
      );

      // Se il consenso e' gia' stato dato in una sessione precedente,
      // gli annunci possono partire subito senza aspettare il modulo.
      await _startAdsIfAllowed();
    } catch (e) {
      debugPrint('Errore nel flusso di consenso: $e');
    }
  }

  /// Avvia l'SDK degli annunci solo se il consenso lo permette.
  static Future<void> _startAdsIfAllowed() async {
    if (_initialized || _adsStarting) return;
    try {
      final canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (!canRequestAds || _initialized || _adsStarting) return;

      _adsStarting = true;
      await MobileAds.instance.initialize();
      _initialized = true;
      _preload();
    } catch (e) {
      debugPrint('Errore inizializzazione annunci: $e');
    } finally {
      _adsStarting = false;
    }
  }

  /// true se la legge richiede di offrire all'utente un pulsante per
  /// modificare le scelte sulla privacy (da mostrare nelle impostazioni).
  static Future<bool> isPrivacyOptionsRequired() async {
    if (!_isSupported) return false;
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      return false;
    }
  }

  /// Riapre il modulo con cui l'utente puo' cambiare le scelte sulla privacy.
  static void showPrivacyOptions() {
    if (!_isSupported) return;
    ConsentForm.showPrivacyOptionsForm((formError) {
      if (formError != null) {
        debugPrint(
            'Modulo privacy non mostrato: ${formError.errorCode} ${formError.message}');
      }
    });
  }

  /// Carica in anticipo il prossimo annuncio, cosi' e' pronto al clic.
  static void _preload() {
    if (!_initialized || _isLoading || _ad != null) return;
    _isLoading = true;
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _isLoading = false;
          debugPrint('Annuncio non caricato: ${error.message}');
        },
      ),
    );
  }

  /// Mostra l'annuncio (se pronto) e termina solo quando l'utente lo ha
  /// chiuso. Se l'annuncio non e' disponibile, se manca il consenso o se ne
  /// e' stato mostrato uno da poco, termina subito: l'utente non resta mai
  /// bloccato.
  static Future<void> showBeforeLeaving() async {
    if (!_isSupported || _isShowing) return;

    final ad = _ad;
    if (ad == null) {
      _preload();
      return;
    }

    final last = _lastShownAt;
    if (last != null && DateTime.now().difference(last) < minInterval) {
      return;
    }

    final completer = Completer<void>();
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    _isShowing = true;
    _ad = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Annuncio non mostrato: ${error.message}');
        ad.dispose();
        finish();
      },
    );

    try {
      await ad.show();
      _lastShownAt = DateTime.now();
      await completer.future;
    } catch (e) {
      debugPrint('Errore durante la visualizzazione dell\'annuncio: $e');
    } finally {
      _isShowing = false;
      _preload();
    }
  }
}
