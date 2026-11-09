import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _acceptTermsAndPrivacy = false;

  Future<void> _savePrivacyConsentToFirestore(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'privacyAccepted': true,
        'privacyAcceptedAt': FieldValue.serverTimestamp(),
        'hearts': 5, //
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Errore nel salvataggio consenso privacy: $e');
    }
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip, color: Colors.purple),
            SizedBox(width: 8),
            Text('Informativa Privacy & GDPR', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Informativa sulla Privacy e Trattamento Dati (GDPR)\n\n'
            '1. Titolare del Trattamento\n'
            'SideBySide rispetta la tua privacy e protegge i tuoi dati personali in conformità al Regolamento UE 2016/679 (GDPR).\n\n'
            '2. Dati Raccolti\n'
            'Raccogliamo l\'indirizzo email, le informazioni del profilo, le foto caricate e la posizione (se abilitata) per offrirti i servizi della community.\n\n'
            '3. Finalità del Trattamento\n'
            'I tuoi dati vengono usati esclusivamente per la gestione dell\'account, le interazioni con gli altri utenti e il corretto funzionamento dell\'app.\n\n'
            '4. Diritti dell\'Utente\n'
            'Puoi in qualsiasi momento accedere, modificare o richiedere la cancellazione completa del tuo account e dei tuoi dati personali dalla sezione Profilo.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Ho Capito', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (!_acceptTermsAndPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Devi accettare l\'Informativa sulla Privacy per proseguire. ⚠️'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Inserisci email e password! ⚠️'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await _savePrivacyConsentToFirestore(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Errore durante il login';
      if (e.code == 'user-not-found') {
        message = 'Nessun utente trovato con questa email.';
      } else if (e.code == 'wrong-password') {
        message = 'Password errata.';
      } else if (e.code == 'invalid-email') {
        message = 'Formato email non valido.';
      } else if (e.code == 'invalid-credential') {
        message = 'Credenziali non valide o errate.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    if (!_acceptTermsAndPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Devi accettare l\'Informativa sulla Privacy per proseguire. ⚠️'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithPopup(googleProvider);

      if (userCredential.user != null) {
        await _savePrivacyConsentToFirestore(userCredential.user!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accesso con Google effettuato con successo! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore Google Login: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loginWithPhone() {
    if (!_acceptTermsAndPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Devi accettare l\'Informativa sulla Privacy per proseguire. ⚠️'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Accedi con Telefono'),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Numero (es. +393400000000)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () async {
              Navigator.pop(context);
              String phoneNumber = phoneController.text.trim();
              if (phoneNumber.isEmpty) return;

              setState(() => _isLoading = true);

              try {
                await FirebaseAuth.instance.verifyPhoneNumber(
                  phoneNumber: phoneNumber,
                  verificationCompleted:
                      (PhoneAuthCredential credential) async {
                    UserCredential userCred = await FirebaseAuth.instance
                        .signInWithCredential(credential);
                    if (userCred.user != null) {
                      await _savePrivacyConsentToFirestore(userCred.user!);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Accesso automatico riuscito! 🎉'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  verificationFailed: (FirebaseAuthException e) {
                    debugPrint("ERRORE PHONE: ${e.code} - ${e.message}");
                    if (mounted) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Errore verifica: ${e.message ?? e.code}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  codeSent: (String verificationId, int? resendToken) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      _showSmsCodeDialog(verificationId);
                    }
                  },
                  codeAutoRetrievalTimeout: (String verificationId) {},
                );
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Errore: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Invia Codice',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSmsCodeDialog(String verificationId) {
    TextEditingController smsCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Inserisci Codice SMS'),
        content: TextField(
          controller: smsCodeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Codice a 6 cifre ricevuto',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () async {
              Navigator.pop(context);
              String smsCode = smsCodeController.text.trim();
              if (smsCode.isEmpty) return;

              setState(() => _isLoading = true);

              try {
                PhoneAuthCredential credential = PhoneAuthProvider.credential(
                  verificationId: verificationId,
                  smsCode: smsCode,
                );
                UserCredential userCred = await FirebaseAuth.instance
                    .signInWithCredential(credential);

                if (userCred.user != null) {
                  await _savePrivacyConsentToFirestore(userCred.user!);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Accesso con telefono riuscito! 🎉'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Codice non valido: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Verifica e Accedi',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: const Text('Accedi',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Icon(Icons.favorite, color: Colors.purple, size: 32),
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Side',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple)),
                  Text('BySide',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                        color: Colors.grey),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: Colors.purple,
                  value: _acceptTermsAndPrivacy,
                  onChanged: (bool? value) =>
                      setState(() => _acceptTermsAndPrivacy = value ?? false),
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Accetto i ', style: TextStyle(fontSize: 11)),
                      GestureDetector(
                        onTap: _showPrivacyPolicyDialog,
                        child: const Text(
                          'Termini e Privacy (GDPR)',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Accedi',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 25)),
                  onPressed: () {},
                  child: const Text('Non hai un account? Registrati ora',
                      style: TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ),
              const Divider(height: 16, thickness: 1),
              const Center(
                  child: Text('Oppure accedi con',
                      style: TextStyle(color: Colors.grey, fontSize: 11))),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: const Icon(Icons.g_mobiledata,
                        color: Colors.red, size: 24),
                    label: const Text('Google', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isLoading ? null : _loginWithPhone,
                    icon:
                        const Icon(Icons.phone, color: Colors.green, size: 16),
                    label:
                        const Text('Telefono', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
