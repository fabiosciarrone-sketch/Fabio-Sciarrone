import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_model.dart';

class EventsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Recupera tutti gli eventi da Firestore
  Stream<List<EventModel>> getEvents() {
    return _db
        .collection('events')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList());
  }
}
