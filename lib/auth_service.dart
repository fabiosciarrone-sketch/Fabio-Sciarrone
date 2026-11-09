import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

import 'notification_service.dart';

/// Logica di autenticazione condivisa (email, Google, telefono).
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crea il documento utente su Firestore al primo accesso
  /// (bonus iscrizione +10 punti) e registra il consenso privacy.
  /// Per gli utenti già esistenti aggiorna solo i campi mancanti.
  static Future<void> ensureUserDocument(User user,
      {bool privacyAccepted = true}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      final doc = await ref.get();
      final Map<String, dynamic> data = {
        if (privacyAccepted) 'privacyAccepted': true,
        if (privacyAccepted) 'privacyAcceptedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      if (!doc.exists) {
        final email = user.email ?? '';
        final fallbackName = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : (email.isNotEmpty ? email.split('@')[0] : 'Utente');
        data.addAll({
          'email': email,
          'phoneNumber': user.phoneNumber ?? '',
          'name': fallbackName,
          if (user.photoURL != null) 'profilePhotoUrl': user.photoURL,
          'points': 10, // 🎁 Bonus iscrizione
          'level': 'Profilo attivo',
          'hearts': 5,
          'isPremium': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final existing = doc.data() ?? {};
        if ((existing['phoneNumber'] ?? '').toString().isEmpty &&
            user.phoneNumber != null) {
          data['phoneNumber'] = user.phoneNumber;
        }
        if ((existing['email'] ?? '').toString().isEmpty &&
            user.email != null) {
          data['email'] = user.email;
        }
      }

      await ref.set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Errore creazione documento utente: $e');
    }

    // Token notifiche push
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await NotificationService.saveTokenToDatabase(token);
    } catch (e) {
      debugPrint('Token notifiche non salvato: $e');
    }
  }

  // ---------------------------------------------------------------- EMAIL

  static Future<void> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    if (cred.user != null) await ensureUserDocument(cred.user!);
  }

  static Future<void> registerWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    if (cred.user != null) await ensureUserDocument(cred.user!);
  }

  /// Invia l'email di Firebase con il link per impostare una nuova password.
  static Future<void> sendPasswordReset(String email) async {
    await _auth.setLanguageCode('it');
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // --------------------------------------------------------------- GOOGLE

  /// Accesso / registrazione con Google.
  /// Restituisce false se l'utente ha annullato.
  static Future<bool> signInWithGoogle() async {
    UserCredential cred;
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      cred = await _auth.signInWithPopup(provider);
    } else {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      // Forza la scelta dell'account ogni volta
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) return false; // annullato
      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      cred = await _auth.signInWithCredential(credential);
    }
    if (cred.user != null) await ensureUserDocument(cred.user!);
    return true;
  }

  static Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // ------------------------------------------------------------- MESSAGGI

  /// Traduce i codici errore di Firebase in messaggi comprensibili.
  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'Nessun utente trovato con questa email.';
        case 'wrong-password':
        case 'invalid-credential':
        case 'INVALID_LOGIN_CREDENTIALS':
          return 'Email o password non corrette.';
        case 'invalid-email':
          return 'Formato email non valido.';
        case 'email-already-in-use':
          return 'Esiste già un account con questa email.';
        case 'weak-password':
          return 'Password troppo debole (minimo 6 caratteri).';
        case 'user-disabled':
          return 'Questo account è stato disattivato.';
        case 'too-many-requests':
          return 'Troppi tentativi. Riprova tra qualche minuto.';
        case 'network-request-failed':
          return 'Connessione assente. Controlla la rete.';
        case 'account-exists-with-different-credential':
          return 'Questa email è già registrata con un altro metodo di accesso.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return 'Accesso annullato.';
        case 'invalid-phone-number':
          return 'Numero di telefono non valido. Usa il formato +39...';
        case 'invalid-verification-code':
          return 'Codice OTP errato. Controlla e riprova.';
        case 'session-expired':
        case 'code-expired':
          return 'Il codice è scaduto. Richiedine uno nuovo.';
        case 'quota-exceeded':
          return 'Limite di SMS raggiunto. Riprova più tardi.';
        case 'missing-client-identifier':
        case 'app-not-authorized':
          return 'App non autorizzata per gli SMS (controlla SHA-1 su Firebase).';
        case 'operation-not-allowed':
          return 'Metodo di accesso non abilitato su Firebase.';
        default:
          return e.message ?? 'Errore (${e.code})';
      }
    }
    return 'Errore: $e';
  }
}
