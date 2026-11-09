import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'home_screen.dart';
import 'auth_screen.dart';
import 'notification_service.dart';

// Chiave globale per gestire la navigazione e mostrare i popup delle notifiche
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializzazione sicura di Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Errore critico durante l'inizializzazione di Firebase: $e");
  }

  // Inizializzazione sicura del servizio notifiche
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("Errore durante l'inizializzazione delle notifiche: $e");
  }

  // Avvia l'applicazione in ogni caso, evitando lo schermo bianco
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Collegata qui per i popup in primo piano
      title: 'SideBySide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const HomeScreen();
          }

          return const AuthScreen();
        },
      ),
    );
  }
}
