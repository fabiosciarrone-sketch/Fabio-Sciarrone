import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'phone_auth_screen.dart';

/// Schermata di accesso / registrazione.
/// Metodi: Email + password, Google, Numero di telefono (OTP).
/// Include "Password dimenticata?" con invio email di reset.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _acceptPrivacy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  /// Per registrazione e accessi social serve il consenso privacy
  /// (possono creare un nuovo account).
  bool _checkPrivacy() {
    if (_acceptPrivacy) return true;
    _snack("Devi accettare l'Informativa sulla Privacy per proseguire. ⚠️",
        color: Colors.orange);
    return false;
  }

  // ------------------------------------------------------------- EMAIL

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _snack('Inserisci email e password! ⚠️', color: Colors.orange);
      return;
    }
    if (!_isLogin) {
      if (!_checkPrivacy()) return;
      if (password.length < 6) {
        _snack('La password deve avere almeno 6 caratteri.',
            color: Colors.orange);
        return;
      }
      if (password != _confirmController.text) {
        _snack('Le password non coincidono.', color: Colors.orange);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await AuthService.signInWithEmail(email, password);
      } else {
        await AuthService.registerWithEmail(email, password);
      }
    } catch (e) {
      _snack(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------------ GOOGLE

  Future<void> _google() async {
    if (!_checkPrivacy()) return;
    setState(() => _isLoading = true);
    try {
      final ok = await AuthService.signInWithGoogle();
      if (ok) {
        _snack('Accesso con Google effettuato! 🎉', color: Colors.green);
      }
    } catch (e) {
      _snack(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------- TELEFONO

  void _phone() {
    if (!_checkPrivacy()) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
    );
  }

  // ------------------------------------------------ PASSWORD DIMENTICATA

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();
    bool sending = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: Colors.purple),
              SizedBox(width: 8),
              Text('Password dimenticata'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Inserisci l'email del tuo account: ti invieremo un link per impostare una nuova password.",
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Inserisci la tua email';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value)) {
                      return 'Email non valida';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(dialogContext),
              child:
                  const Text('Annulla', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white),
              onPressed: sending
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => sending = true);
                      try {
                        await AuthService.sendPasswordReset(controller.text);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        _showResetSent(controller.text.trim());
                      } catch (e) {
                        setDialogState(() => sending = false);
                        _snack(AuthService.friendlyError(e));
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Invia link'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetSent(String email) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.mark_email_read, color: Colors.green, size: 48),
        title: const Text('Controlla la tua email'),
        content: Text(
          "Se esiste un account associato a $email, riceverai a breve un'email con il link per creare una nuova password.\n\nControlla anche la cartella Spam.",
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- PRIVACY

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip, color: Colors.purple),
            SizedBox(width: 8),
            Expanded(
                child: Text('Informativa Privacy & GDPR',
                    style: TextStyle(fontSize: 18))),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Informativa sulla Privacy e Trattamento Dati (GDPR)\n\n'
            '1. Titolare del Trattamento\n'
            'SideBySide rispetta la tua privacy e protegge i tuoi dati personali in conformità al Regolamento UE 2016/679 (GDPR).\n\n'
            '2. Dati Raccolti\n'
            "Raccogliamo l'indirizzo email o il numero di telefono, le informazioni del profilo, le foto caricate e la posizione (se abilitata) per offrirti i servizi della community.\n\n"
            '3. Finalità del Trattamento\n'
            "I tuoi dati vengono usati esclusivamente per la gestione dell'account, le interazioni con gli altri utenti e il corretto funzionamento dell'app.\n\n"
            "4. Diritti dell'Utente\n"
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

  // ------------------------------------------------------------------- UI

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _socialButton({
    required String label,
    required Widget icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        icon: icon,
        label: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Accedi' : 'Registrati',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.favorite, size: 72, color: Colors.purple),
                const SizedBox(height: 12),
                const Text(
                  'SideBySide',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // ---- Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: _decoration('Email', Icons.email),
                ),
                const SizedBox(height: 16),

                // ---- Password
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: [
                    _isLogin ? AutofillHints.password : AutofillHints.newPassword
                  ],
                  decoration: _decoration(
                    'Password',
                    Icons.lock,
                    suffix: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  onSubmitted: (_) => _isLogin ? _submit() : null,
                ),

                // ---- Conferma password (solo registrazione)
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscurePassword,
                    decoration:
                        _decoration('Conferma password', Icons.lock_outline),
                    onSubmitted: (_) => _submit(),
                  ),
                ],

                // ---- Password dimenticata
                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      child: const Text('Password dimenticata?',
                          style: TextStyle(color: Colors.purple)),
                    ),
                  )
                else
                  const SizedBox(height: 12),

                // ---- Consenso privacy
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.purple,
                    value: _acceptPrivacy,
                    onChanged: (v) =>
                        setState(() => _acceptPrivacy = v ?? false),
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Accetto i ', style: TextStyle(fontSize: 12)),
                        GestureDetector(
                          onTap: _showPrivacyPolicyDialog,
                          child: const Text(
                            'Termini e Privacy (GDPR)',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Pulsante principale
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            _isLogin ? 'Accedi' : 'Registrati',
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                // ---- Divisore
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        _isLogin ? 'oppure accedi con' : 'oppure registrati con',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // ---- Google
                _socialButton(
                  label: 'Continua con Google',
                  icon: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Text('G',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4285F4))),
                  ),
                  onPressed: _isLoading ? null : _google,
                ),
                const SizedBox(height: 12),

                // ---- Telefono
                _socialButton(
                  label: 'Continua con il numero di telefono',
                  icon: const Icon(Icons.phone_iphone, color: Colors.green),
                  onPressed: _isLoading ? null : _phone,
                ),
                const SizedBox(height: 20),

                // ---- Alterna Accedi / Registrati
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _isLogin = !_isLogin;
                            _confirmController.clear();
                          }),
                  child: Text(
                    _isLogin
                        ? 'Non hai un account? Registrati'
                        : 'Hai già un account? Accedi',
                    style: const TextStyle(
                        color: Colors.purple, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
