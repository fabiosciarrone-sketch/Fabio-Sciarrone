class PlaceModel {
  final String name;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final double? rating;
  final String? photoReference;
  double? distance; // Distanza in metri
  final int? activeUsersCount; // <--- Aggiunto per l'affluenza reale

  PlaceModel({
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.photoReference,
    this.distance,
    this.activeUsersCount, // <--- Aggiunto nel costruttore
  });
}
