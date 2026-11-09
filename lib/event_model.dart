import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String locationName;
  final String city;
  final DateTime date;
  final String ticketUrl;
  final String category;
  final double priceFrom;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.locationName,
    required this.city,
    required this.date,
    required this.ticketUrl,
    required this.category,
    required this.priceFrom,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      locationName: data['locationName'] ?? '',
      city: data['city'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      ticketUrl: data['ticketUrl'] ?? '',
      category: data['category'] ?? '',
      priceFrom: (data['priceFrom'] ?? 0).toDouble(),
    );
  }
}
