import 'package:cloud_firestore/cloud_firestore.dart';

class SeedService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> addDummyUsers() async {
    var dummyUsers = [
      {
        'id': 'martina_id', // ID fisso per evitare duplicati
        'name': 'Martina',
        'age': 24,
        'bio': 'Amo il fitness e il buon cibo a Catania! 🌴',
        'profilePhotoUrl':
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
        'isDummy': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'marco_id', // ID fisso per evitare duplicati
        'name': 'Marco',
        'age': 26,
        'bio': 'Palestra, bar e serate in centro 🏋️‍♂️',
        'profilePhotoUrl':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
        'isDummy': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (var user in dummyUsers) {
      String userId = user['id'] as String;
      // Usiamo .doc(userId).set() con merge: true:
      // se l'utente non esiste lo crea, se esiste lo aggiorna senza duplicarlo!
      await _firestore
          .collection('users')
          .doc(userId)
          .set(user, SetOptions(merge: true));
    }
  }
}
