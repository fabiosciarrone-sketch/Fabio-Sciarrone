import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  double _rating = 5.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  // Funzione per inviare la recensione e assegnare +15 punti
  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_venueController.text.trim().isEmpty ||
        _reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Inserisci il nome del locale e il testo della recensione.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Salva la recensione nella collezione 'reviews'
      await FirebaseFirestore.instance.collection('reviews').add({
        'userId': user.uid,
        'userName': user.displayName ?? user.email?.split('@')[0] ?? 'Utente',
        'venueName': _venueController.text.trim(),
        'reviewText': _reviewController.text.trim(),
        'rating': _rating,
        'likes': 0,
        'likedBy': [],
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. I +15 punti li assegna la Cloud Function 'awardPointsOnReview'

      _venueController.clear();
      _reviewController.clear();
      setState(() => _rating = 5.0);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recensione pubblicata con successo! +15 punti 🏆'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Funzione per mettere Mi Piace e assegnare +5 punti a chi la vota (o incentivare l'interazione)
  Future<void> _toggleLike(String reviewId, List<dynamic> likedBy) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reviewRef =
        FirebaseFirestore.instance.collection('reviews').doc(reviewId);
    bool hasLiked = likedBy.contains(user.uid);

    try {
      if (hasLiked) {
        await reviewRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([user.uid]),
        });
      } else {
        await reviewRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([user.uid]),
        });
        // I +5 punti per il Mi Piace li assegna la Cloud Function
        // 'awardPointsOnReviewLike' (una sola volta per recensione).
      }
    } catch (e) {
      debugPrint("Errore like recensione: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community & Recensioni 🌟'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          // Sezione per scrivere una recensione
          ExpansionTile(
            title: const Text(
              'Scrivi una recensione su un locale partner ✍️',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _venueController,
                      decoration: const InputDecoration(
                        labelText: 'Nome del Locale Partner',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reviewController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'La tua recensione / consigli...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Valutazione: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Slider(
                          value: _rating,
                          min: 1,
                          max: 5,
                          divisions: 4,
                          activeColor: Colors.purple,
                          label: _rating.toStringAsFixed(1),
                          onChanged: (val) => setState(() => _rating = val),
                        ),
                        Text('⭐ ${_rating.toStringAsFixed(1)}',
                            style: const TextStyle(fontWeight: FontWeight.bold))
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSubmitting ? null : _submitReview,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Pubblica e guadagna +15 punti 🏆'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1),

          // Lista delle recensioni in tempo reale da Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nessuna recensione nella community.\nSii il primo a scriverne una! 🌟',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final reviews = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review =
                        reviews[index].data() as Map<String, dynamic>;
                    final reviewId = reviews[index].id;
                    final userName = review['userName'] ?? 'Utente';
                    final venueName = review['venueName'] ?? 'Locale';
                    final reviewText = review['reviewText'] ?? '';
                    final rating = review['rating'] ?? 5.0;
                    final likes = review['likes'] ?? 0;
                    final List<dynamic> likedBy = review['likedBy'] ?? [];
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final hasLiked = currentUser != null &&
                        likedBy.contains(currentUser.uid);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  venueName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.purple),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        color: Colors.amber, size: 18),
                                    Text(' $rating',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Da: $userName',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text(reviewText,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      _toggleLike(reviewId, likedBy),
                                  icon: Icon(
                                    hasLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: Colors.pink,
                                    size: 20,
                                  ),
                                  label: Text('$likes Mi piace (+5 pt)',
                                      style:
                                          const TextStyle(color: Colors.pink)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
