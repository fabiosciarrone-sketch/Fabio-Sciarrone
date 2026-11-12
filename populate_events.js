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

// Immagini generiche (le stesse usate finora)
const IMG_CONCERTO = 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819';
const IMG_TEATRO = 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf';

// Pagine dove trovare info e biglietti
const URL_TICKETONE_CT = buildAwinLink('https://www.ticketone.it/city/catania-1936/concerti-55/');
const URL_METROPOLITAN = 'https://www.vivaticket.com/it/venue/metropolitan-catania/512060059';
const URL_SICILIASPETTACOLI = 'https://www.siciliaspettacoli.it/concerti-a-catania/';
const URL_BALARM = 'https://www.balarm.it/tutti-gli-eventi-a-catania-e-provincia-dei-prossimi-mesi';

// Vecchi eventi di prova da eliminare
const oldTestEventIds = ['ev_ct_001', 'ev_ct_002'];

// Crea la data con il fuso orario italiano (dicembre = +01:00)
function when(isoLocal) {
  return Timestamp.fromDate(new Date(`${isoLocal}:00+01:00`));
}

// Eventi reali a Catania - dicembre 2026 (verificati online l'11/11/2026)
// NOTA: priceFrom e' 0 dove il prezzo non e' stato verificato.
// NOTA: dove l'orario non era pubblicato e' stato messo 21:00 (l'app mostra solo la data).
const cataniaEvents = [
  {
    id: 'ev_ct_2612_01',
    title: 'Glazyhaze live',
    description: 'Dream pop e shoegaze dal vivo per la rassegna Pulsar.',
    imageUrl: IMG_CONCERTO,
    locationName: 'Zō Centro Culture Contemporanee',
    city: 'Catania',
    date: when('2026-12-04T21:00'),
    ticketUrl: URL_SICILIASPETTACOLI,
    category: 'Concerti',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_02',
    title: 'Cozy Room con Vladimir Ivkovic',
    description: 'Notte clubbing di musica elettronica con ospite internazionale. Apertura porte 22:30, ingresso 18+.',
    imageUrl: IMG_CONCERTO,
    locationName: 'Mercati Generali',
    city: 'Catania',
    date: when('2026-12-05T22:30'),
    ticketUrl: 'https://www.siciliaspettacoli.it/evento/cozy-room-ai-mercati-generali-con-vladimir-ivkovic/',
    category: 'Discoteca',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_03',
    title: 'Christmas Town - La città del Natale (fino al 6 gennaio)',
    description: 'Il grande parco a tema natalizio: pista di pattinaggio su ghiaccio, giostre, ruota panoramica, Casa di Babbo Natale, spettacoli e parate. Dal 5 dicembre al 6 gennaio.',
    imageUrl: IMG_TEATRO,
    locationName: 'Le Ciminiere',
    city: 'Catania',
    date: when('2026-12-05T10:00'),
    ticketUrl: 'https://www.ciaotickets.com/it/biglietti/christmas-town-la-citta-del-natale-catania',
    category: 'Natale',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_04',
    title: 'Scott Hamilton Quartet - Catania Sea Jazz Festival',
    description: 'Il sassofonista americano Scott Hamilton apre il Catania Sea Jazz Festival.',
    imageUrl: IMG_CONCERTO,
    locationName: 'Teatro ABC',
    city: 'Catania',
    date: when('2026-12-07T21:00'),
    ticketUrl: URL_SICILIASPETTACOLI,
    category: 'Concerti',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_05',
    title: 'Lo Schiaccianoci - Compagnia Almatanz',
    description: 'Il balletto di Natale per eccellenza sulle musiche di Čajkovskij.',
    imageUrl: IMG_TEATRO,
    locationName: 'Teatro Ambasciatori',
    city: 'Catania',
    date: when('2026-12-07T20:30'),
    ticketUrl: 'https://www.enjoysicilia.it/en/events/concerti-spettacoli-catania/',
    category: 'Teatro',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_06',
    title: 'Arriva Lucilla',
    description: 'Lo spettacolo musicale per bambini e famiglie.',
    imageUrl: IMG_TEATRO,
    locationName: 'Teatro Metropolitan',
    city: 'Catania',
    date: when('2026-12-08T18:00'),
    ticketUrl: URL_METROPOLITAN,
    category: 'Famiglie',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_07',
    title: 'Round About Miles - Ottaviano e Sbisà',
    description: 'Omaggio jazz a Miles Davis per la stagione di Catania Jazz.',
    imageUrl: IMG_CONCERTO,
    locationName: 'Teatro Metropolitan',
    city: 'Catania',
    date: when('2026-12-10T21:00'),
    ticketUrl: URL_SICILIASPETTACOLI,
    category: 'Concerti',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_08',
    title: 'Le Coliche - 10 anni di Coliche e siamo ancora vivi',
    description: 'Lo show comico de Le Coliche per i dieci anni di carriera.',
    imageUrl: IMG_TEATRO,
    locationName: 'Teatro Metropolitan',
    city: 'Catania',
    date: when('2026-12-11T21:00'),
    ticketUrl: URL_METROPOLITAN,
    category: 'Comicità',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_09',
    title: 'Back to Hawkins - Il musical ispirato a Stranger Things',
    description: 'Un viaggio verso Hawkins tra musica anni \'80, scene cult e atmosfere cinematografiche.',
    imageUrl: IMG_TEATRO,
    locationName: 'Teatro Metropolitan',
    city: 'Catania',
    date: when('2026-12-12T21:00'),
    ticketUrl: URL_BALARM,
    category: 'Musical',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_10',
    title: 'Enrico Brignano - Bello di Mamma! (16 e 17 dicembre)',
    description: 'Enrico Brignano torna in Sicilia con il suo nuovo show. Due serate: 16 e 17 dicembre.',
    imageUrl: IMG_TEATRO,
    locationName: 'Teatro Metropolitan',
    city: 'Catania',
    date: when('2026-12-16T21:00'),
    ticketUrl: URL_BALARM,
    category: 'Comicità',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_11',
    title: 'ABBAdream',
    description: 'Il tributo agli ABBA con tutti i grandi successi dal vivo.',
    imageUrl: IMG_CONCERTO,
    locationName: 'Teatro Metropolitan',
    city: 'Catania',
    date: when('2026-12-18T21:00'),
    ticketUrl: URL_TICKETONE_CT,
    category: 'Concerti',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_12',
    title: 'South Side - Alessandro Presti',
    description: 'Il trombettista Alessandro Presti chiude il 2026 del Monk Jazz Club.',
    imageUrl: IMG_CONCERTO,
    locationName: 'Monk Jazz Club',
    city: 'Catania',
    date: when('2026-12-18T21:00'),
    ticketUrl: URL_SICILIASPETTACOLI,
    category: 'Concerti',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_13',
    title: 'Paolo Fresu - Christmas Songs',
    description: 'Il concerto di Natale di Paolo Fresu per l\'Associazione Musicale Etnea.',
    imageUrl: IMG_CONCERTO,
    locationName: 'Teatro Stabile di Catania',
    city: 'Catania',
    date: when('2026-12-21T21:00'),
    ticketUrl: 'https://www.ame.ct.it/prossimi-eventi/',
    category: 'Concerti',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_14',
    title: 'Tim Burton Intimate Music Experience',
    description: 'Le colonne sonore dei film di Tim Burton suonate dal vivo.',
    imageUrl: IMG_CONCERTO,
    locationName: 'Teatro Metropolitan',
    city: 'Catania',
    date: when('2026-12-26T20:30'),
    ticketUrl: 'https://www.enjoysicilia.it/en/events/concerti-spettacoli-catania/',
    category: 'Concerti',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_15',
    title: 'Anna Castiglia - La paura in tasca Tour',
    description: 'La cantautrice catanese torna a casa per chiudere l\'anno con le nuove canzoni.',
    imageUrl: IMG_CONCERTO,
    locationName: 'Teatro Metropolitan',
    city: 'Catania',
    date: when('2026-12-29T21:00'),
    ticketUrl: URL_TICKETONE_CT,
    category: 'Concerti',
    priceFrom: 0
  },
  {
    id: 'ev_ct_2612_16',
    title: 'Mario Incudine e I Lautari - La cantata dei pastori',
    description: 'Musica e tradizione siciliana del Natale con Mario Incudine e I Lautari.',
    imageUrl: IMG_CONCERTO,
    locationName: 'Teatro Metropolitan',
    city: 'Catania',
    date: when('2026-12-30T21:00'),
    ticketUrl: URL_SICILIASPETTACOLI,
    category: 'Concerti',
    priceFrom: 0
  }
];

async function seedFirestore() {
  console.log('🚀 Avvio caricamento eventi su Firestore...');

  for (const oldId of oldTestEventIds) {
    await db.collection('events').doc(oldId).delete();
    console.log(`🗑️ Eliminato vecchio evento di prova: ${oldId}`);
  }

  for (const event of cataniaEvents) {
    await db.collection('events').doc(event.id).set(
      { ...event, createdAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
    console.log(`✅ Inserito/Aggiornato evento: ${event.title}`);
  }
  console.log(`🎉 Popolamento completato: ${cataniaEvents.length} eventi caricati.`);
  process.exit(0);
}

seedFirestore().catch((err) => {
  console.error('❌ Errore durante l\'inserimento:', err);
  process.exit(1);
});
