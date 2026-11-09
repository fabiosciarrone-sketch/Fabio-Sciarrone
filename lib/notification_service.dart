import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // Importato per usare la navigatorKey globale

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Canale Android usato anche dalla Cloud Function (channelId)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'sidebyside_chat_channel',
    'Notifiche Chat',
    description: 'Canale per le notifiche dei messaggi',
    importance: Importance.max,
  );

  static bool _localNotificationsReady = false;

  // 1. Metodo di inizializzazione chiamato dal main.dart
  static Future<void> initialize() async {
    // Chiede i permessi all'utente
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('Permessi notifiche: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Errore richiesta permessi notifiche: $e');
    }

    // Le notifiche locali esistono solo su Android/iOS: sul web il plugin
    // non è supportato e prima mandava in errore tutta l'inizializzazione.
    if (!kIsWeb) {
      try {
        const initializationSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        );
        await _localNotificationsPlugin.initialize(initializationSettings);
        await _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
        _localNotificationsReady = true;
      } catch (e) {
        debugPrint('Errore inizializzazione notifiche locali: $e');
      }
    }

    // Messaggi ricevuti con l'app aperta (in primo piano).
    // Nota: la notifica viene già salvata su Firestore dalla Cloud Function,
    // quindi qui la mostriamo soltanto (una volta sola).
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      if (!kIsWeb && _localNotificationsReady) {
        // Android/iOS: notifica di sistema
        _localNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      } else {
        // Web: piccolo avviso in basso dentro l'app
        _showInAppBanner(notification.title, notification.body);
      }
    });

    // Click sulla notifica quando l'app è in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App aperta da notifica: ${message.notification?.title}');
    });

    // Click quando l'app era completamente chiusa
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('App avviata da notifica: ${message.notification?.title}');
      }
    });

    // Se il token cambia lo aggiorniamo automaticamente
    _firebaseMessaging.onTokenRefresh.listen(saveTokenToDatabase);
  }

  static void _showInAppBanner(String? title, String? body) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title ?? 'Nuova notifica',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (body != null && body.isNotEmpty)
              Text(body, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  /// true se l'errore è un "permesso negato" di Firestore.
  static bool isPermissionDenied(Object error) =>
      error is FirebaseException && error.code == 'permission-denied';

  /// Segna come lette tutte le notifiche dell'utente corrente.
  /// Non lancia mai eccezioni: se le regole di Firestore non permettono
  /// l'aggiornamento, registra l'errore in console e restituisce false,
  /// senza bloccare l'interfaccia.
  static Future<bool> markAllNotificationsAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final unread = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();
      if (unread.docs.isEmpty) return true;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      return true;
    } catch (e) {
      if (isPermissionDenied(e)) {
        debugPrint('Notifiche: permessi Firestore insufficienti per segnarle '
            'come lette. Controlla le regole della collezione notifications.');
      } else {
        debugPrint('Errore aggiornamento notifiche lette: $e');
      }
      return false;
    }
  }

  // 2. Salva il token del dispositivo sul profilo utente (chiamato al login)
  static Future<void> saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (isPermissionDenied(e)) {
        debugPrint('Token FCM non salvato: permessi Firestore insufficienti '
            'sul documento users/${user.uid}.');
      } else {
        debugPrint('Errore salvataggio token FCM: $e');
      }
    }
  }
}
