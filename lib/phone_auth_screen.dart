import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';

/// Accesso / registrazione con numero di telefono e codice OTP via SMS.
///
/// Flusso:
/// 1. inserimento numero (prefisso +39 di default)
/// 2. invio SMS (Android: verifyPhoneNumber, Web: signInWithPhoneNumber + reCAPTCHA)
/// 3. inserimento codice a 6 cifre, con reinvio dopo 60 secondi
/// 4. verifica automatica su Android quando l'SMS viene letto dal sistema
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  static const int _resendSeconds = 60;

  final _prefixController = TextEditingController(text: '+39');
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  String? _error;

  String? _verificationId; // Android / iOS
  int? _resendToken; // Android
  ConfirmationResult? _webConfirmation; // Web

  Timer? _timer;
  int _secondsLeft = 0;

  String get _fullNumber {
    var prefix = _prefixController.text.trim();
    if (!prefix.startsWith('+')) prefix = '+$prefix';
    final number = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return '$prefix$number';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _prefixController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() {
      _error = msg;
      _isLoading = false;
    });
  }

  Future<void> _onSignedIn(UserCredential cred) async {
    if (cred.user != null) await AuthService.ensureUserDocument(cred.user!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Accesso con telefono riuscito! 🎉'),
        backgroundColor: Colors.green,
      ),
    );
    // Chiude questa schermata: main.dart mostra la Home grazie a authStateChanges
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ------------------------------------------------------------ INVIO SMS

  Future<void> _sendCode({bool isResend = false}) async {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 6) {
      _showError('Inserisci un numero di telefono valido.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.setLanguageCode('it');

      if (kIsWeb) {
        // Sul web Firebase mostra automaticamente il reCAPTCHA invisibile
        _webConfirmation =
            await FirebaseAuth.instance.signInWithPhoneNumber(_fullNumber);
        if (!mounted) return;
        setState(() {
          _codeSent = true;
          _isLoading = false;
        });
        _startTimer();
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _fullNumber,
        timeout: const Duration(seconds: _resendSeconds),
        forceResendingToken: isResend ? _resendToken : null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android: SMS letto automaticamente
          if (!mounted) return;
          setState(() {
            _isLoading = true;
            if (credential.smsCode != null) {
              _otpController.text = credential.smsCode!;
            }
          });
          try {
            final cred =
                await FirebaseAuth.instance.signInWithCredential(credential);
            await _onSignedIn(cred);
          } catch (e) {
            _showError(AuthService.friendlyError(e));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('ERRORE PHONE: ${e.code} - ${e.message}');
          _showError(AuthService.friendlyError(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _isLoading = false;
          });
          _startTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Codice inviato a $_fullNumber')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _showError(AuthService.friendlyError(e));
    }
  }

  // ------------------------------------------------------- VERIFICA CODICE

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _showError('Il codice deve essere di 6 cifre.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      UserCredential cred;
      if (kIsWeb) {
        if (_webConfirmation == null) {
          _showError('Sessione scaduta. Richiedi un nuovo codice.');
          return;
        }
        cred = await _webConfirmation!.confirm(code);
      } else {
        if (_verificationId == null) {
          _showError('Sessione scaduta. Richiedi un nuovo codice.');
          return;
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        cred = await FirebaseAuth.instance.signInWithCredential(credential);
      }
      await _onSignedIn(cred);
    } catch (e) {
      _showError(AuthService.friendlyError(e));
    }
  }

  void _changeNumber() {
    _timer?.cancel();
    setState(() {
      _codeSent = false;
      _otpController.clear();
      _verificationId = null;
      _webConfirmation = null;
      _secondsLeft = 0;
      _error = null;
    });
  }

  // ----------------------------------------------------------------- UI

  InputDecoration _decoration(String label, {IconData? icon}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accedi con Telefono',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(_codeSent ? Icons.sms : Icons.phone_iphone,
                  size: 64, color: Colors.purple),
              const SizedBox(height: 16),
              Text(
                _codeSent ? 'Inserisci il codice' : 'Il tuo numero',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'Abbiamo inviato un SMS con un codice a 6 cifre al numero $_fullNumber'
                    : 'Ti invieremo un SMS con un codice di verifica.\nSe non hai un account, verrà creato automaticamente.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 28),

              if (!_codeSent) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _prefixController,
                        keyboardType: TextInputType.phone,
                        decoration: _decoration('Prefisso'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                        ],
                        decoration:
                            _decoration('Numero di telefono', icon: Icons.phone),
                        onSubmitted: (_) => _sendCode(),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '------',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) {
                    if (v.length == 6 && !_isLoading) _verifyCode();
                  },
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading
                      ? null
                      : (_codeSent ? _verifyCode : () => _sendCode()),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          _codeSent ? 'Verifica e accedi' : 'Invia codice',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              if (_codeSent) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _isLoading ? null : _changeNumber,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Cambia numero'),
                    ),
                    TextButton(
                      onPressed: (_isLoading || _secondsLeft > 0)
                          ? null
                          : () => _sendCode(isResend: true),
                      child: Text(_secondsLeft > 0
                          ? 'Reinvia tra ${_secondsLeft}s'
                          : 'Reinvia codice'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
