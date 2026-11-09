import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'business_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'legal_screen.dart';
import 'photo_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _profilePhotoBase64 = '';
  List<String> _galleryPhotosBase64 = [];

  int _hearts = 5;
  int _diamonds = 5;
  bool _privacyAccepted = false;
  bool _isPremiumUser = false; // Stato Freemium / Premium (Punto 3)

  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        String loadedProfilePhoto = data['profilePhotoUrl'] ?? '';
        if (loadedProfilePhoto.startsWith('blob:')) {
          loadedProfilePhoto = '';
        }

        List<String> loadedGallery =
            List<String>.from(data['galleryPhotos'] ?? []);
        loadedGallery =
            loadedGallery.where((photo) => !photo.startsWith('blob:')).toList();

        setState(() {
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _cityController.text = data['city'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _ageController.text = (data['age'] ?? '').toString();
          _profilePhotoBase64 = loadedProfilePhoto;
          _galleryPhotosBase64 = loadedGallery;

          _hearts = data['hearts'] ?? 5;
          _diamonds = data['diamonds'] ?? 5;
          _privacyAccepted = data['privacyAccepted'] ?? false;
          _isPremiumUser = data['isPremium'] ?? false;
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'hearts': 5,
          'diamonds': 5,
          'privacyAccepted': false,
          'isPremium': false,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel caricamento profilo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndConvertImage(Function(String) onBase64Ready) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Scegli dalla Galleria'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 500,
                    maxHeight: 500,
                    imageQuality: 25,
                  );
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    if (bytes.length > 150000) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Immagine troppo pesante. Scegline una più piccola.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }
                    final base64String = base64Encode(bytes);
                    onBase64Ready(base64String);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Scatta una Foto'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 500,
                    maxHeight: 500,
                    imageQuality: 25,
                  );
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    if (bytes.length > 150000) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'La foto scattata è troppo pesante. Riprova.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }
                    final base64String = base64Encode(bytes);
                    onBase64Ready(base64String);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _watchAdForReward() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.pink),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.of(context).pop();

      setState(() {
        _hearts += 3;
        _diamonds += 3;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'hearts': _hearts,
          'diamonds': _diamonds,
        }, SetOptions(merge: true));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('🎉 Complimenti! Hai guadagnato +3 Cuori e +3 Diamanti!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_privacyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Devi accettare l\'Informativa sulla Privacy e i Termini GDPR.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 🏆 Calcolo punti basato su completamento profilo (+50) e foto in galleria (+20 per ogni foto)
      int earnedPoints = 50 + (_galleryPhotosBase64.length * 20);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'city': _cityController.text.trim(),
        'bio': _bioController.text.trim(),
        'profilePhotoUrl': _profilePhotoBase64,
        'galleryPhotos': _galleryPhotosBase64,
        'hearts': _hearts,
        'diamonds': _diamonds,
        'privacyAccepted': _privacyAccepted,
        'isPremium': _isPremiumUser,
        'age': int.tryParse(_ageController.text) ?? 0,
        'points': FieldValue.increment(
            earnedPoints), // Assegna i punti per il profilo e le foto
        'level': 'Profilo Completo',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Profilo salvato! +$earnedPoints punti guadagnati 🏆')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il salvataggio: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Il proprietario vede e gestisce SEMPRE tutte le sue foto.
    // Il limite per gli utenti Free vale solo quando visitano il profilo
    // di altri utenti (vedi UserProfileScreen.freeVisiblePhotos).
    final int maxVisiblePhotos = _galleryPhotosBase64.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo Utente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Esci',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Salva',
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SEZIONE PORTAFOGLIO ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade100, Colors.pink.shade50],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.favorite,
                                      color: Colors.red, size: 28),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$_hearts Cuori',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.diamond,
                                      color: Colors.blue, size: 28),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$_diamonds Diamanti',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _watchAdForReward,
                            icon: const Icon(Icons.video_library),
                            label: const Text(
                                'Guarda Video (+3 Cuori & +3 Diamanti)'),
                          ),
                        ],
                      ),
                    ),

                    // --- FOTO PROFILO ---
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          _pickAndConvertImage((base64Str) {
                            setState(() {
                              _profilePhotoBase64 = base64Str;
                            });
                          });
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage:
                                  PhotoUtils.provider(_profilePhotoBase64),
                              child: PhotoUtils.provider(_profilePhotoBase64) ==
                                      null
                                  ? const Icon(Icons.person, size: 50)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                radius: 18,
                                child: const Icon(Icons.camera_alt,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- CAMPI TESTO ---
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Inserisci il nome'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Cognome',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Inserisci il cognome'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Età',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Città',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descrizione / Bio',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // --- GALLERIA FOTO ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Galleria Foto (${_galleryPhotosBase64.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            _pickAndConvertImage((base64Str) {
                              setState(() {
                                _galleryPhotosBase64.add(base64Str);
                              });
                            });
                          },
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Aggiungi Foto'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            maxVisiblePhotos, // Tutte le foto del proprietario
                        itemBuilder: (context, index) {
                          return Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: PhotoUtils.image(
                                      _galleryPhotosBase64[index],
                                      placeholder: Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image,
                                            color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.red,
                                    radius: 14,
                                    child: IconButton(
                                      icon: const Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          _galleryPhotosBase64.removeAt(index);
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Pulsante rapido per l'Area Business
                    ListTile(
                      leading: const Icon(Icons.store, color: Colors.purple),
                      title: const Text('Pass Business & Promo Locali'),
                      subtitle:
                          const Text('Gestisci la tua vetrina e le offerte'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BusinessScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.support_agent, color: Colors.orange),
                      title: const Text('Contatta lo Sviluppatore'),
                      subtitle:
                          const Text('Segnala un problema o invia un feedback'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        final Uri emailUri = Uri(
                          scheme: 'mailto',
                          path: 'fabio.sciarrone@gmail.com',
                          queryParameters: {
                            'subject': 'Supporto App SideBySide',
                            'body':
                                'Ciao Fabio, ti contatto dall\'app per segnalare questo:'
                          },
                        );
                        if (await canLaunchUrl(emailUri)) {
                          await launchUrl(emailUri);
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined,
                          color: Colors.blue),
                      title: const Text('Privacy & Note Legali'),
                      subtitle:
                          const Text('Leggi l\'informativa e i termini d\'uso'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LegalScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // CHECKBOX PRIVACY GDPR
                    CheckboxListTile(
                      title: const Text(
                        'Accetto l\'Informativa sulla Privacy e i Termini GDPR.',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: _privacyAccepted,
                      onChanged: (val) {
                        setState(() {
                          _privacyAccepted = val ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
