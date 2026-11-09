// Service worker per Firebase Cloud Messaging (notifiche push sul web).
// I valori corrispondono alla configurazione "web" di lib/firebase_options.dart
// (progetto Firebase besidr-bd245).
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDFbmiJ2k6N0AI9QlEC29pl5p8PHlopPcg",
  authDomain: "besidr-bd245.firebaseapp.com",
  projectId: "besidr-bd245",
  storageBucket: "besidr-bd245.firebasestorage.app",
  messagingSenderId: "75703560636",
  appId: "1:75703560636:web:855b7997d8e52ef796e3b9",
  measurementId: "G-HQXXP10D39"
});

// Le notifiche con titolo e testo vengono mostrate automaticamente dal browser
// quando la pagina è chiusa o in background.
const messaging = firebase.messaging();
