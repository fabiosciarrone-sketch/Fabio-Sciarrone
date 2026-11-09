import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Note Legali'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Informativa sulla Privacy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'La presente applicazione (SideBySide) rispetta la privacy dei suoi utenti. '
              'Utilizziamo servizi di autenticazione sicuri come Google e il login tramite numero di telefono '
              'al solo scopo di identificare l\'utente e permettere la gestione delle offerte e dei pass promozionali.\n\n'
              'I dati raccolti non vengono ceduti a terzi e sono trattati in conformità con le normative vigenti.',
            ),
            SizedBox(height: 24),
            Text(
              'Termini e Condizioni',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Utilizzando SideBySide, l\'utente accetta i termini di utilizzo del servizio. '
              'L\'applicazione è uno strumento per la visualizzazione di eventi, offerte e promozioni locali. '
              'Lo sviluppatore (Fabio Sciarrone) non si assume alcuna responsabilità per un uso improprio della piattaforma '
              'o per eventuali disservizi temporanei.',
            ),
          ],
        ),
      ),
    );
  }
}
