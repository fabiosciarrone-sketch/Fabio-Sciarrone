const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

// Legge il file di chiave in modo sicuro
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

// Inizializza Firebase Admin con la sintassi modulare
initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

// Funzione per generare il Deep Link di affiliazione Awin per TicketOne
function buildAwinLink(ticketoneUrl) {
  const publisherId = '3129583'; // Il tuo ID Publisher Awin
  const merchantId = '22421';    // ID Merchant TicketOne IT
  return `https://www.awin1.com/cread.php?awinmid=${merchantId}&awinaffid=${publisherId}&ued=${encodeURIComponent(ticketoneUrl)}`;
}

// Lista eventi reali/di prova a Catania
const cataniaEvents = [
  {
    id: 'ev_ct_001',
    title: 'Concerto Live a Catania',
    description: 'Serata di musica dal vivo nella splendida cornice di Catania.',
    imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819',
    locationName: 'Villa Bellini',
    city: 'Catania',
    date: Timestamp.fromDate(new Date('2026-07-20T21:00:00')),
    ticketUrl: buildAwinLink('https://www.ticketone.it/event/concerto-catania/'),
    category: 'Concerti',
    priceFrom: 25.00,
    createdAt: FieldValue.serverTimestamp()
  },
  {
    id: 'ev_ct_002',
    title: 'Spettacolo Teatrale',
    description: 'Grande rappresentazione teatrale dal vivo a Catania.',
    imageUrl: 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf',
    locationName: 'Teatro Massimo Bellini',
    city: 'Catania',
    date: Timestamp.fromDate(new Date('2026-08-05T20:30:00')),
    ticketUrl: buildAwinLink('https://www.ticketone.it/event/teatro-catania/'),
    category: 'Teatro',
    priceFrom: 18.50,
    createdAt: FieldValue.serverTimestamp()
  }
];

async function seedFirestore() {
  console.log('🚀 Avvio caricamento eventi su Firestore...');
  for (const event of cataniaEvents) {
    await db.collection('events').doc(event.id).set(event, { merge: true });
    console.log(`✅ Inserito/Aggiornato evento: ${event.title}`);
  }
  console.log('🎉 Popolamento completato con successo!');
  process.exit(0);
}

seedFirestore().catch((err) => {
  console.error('❌ Errore durante l\'inserimento:', err);
  process.exit(1);
});