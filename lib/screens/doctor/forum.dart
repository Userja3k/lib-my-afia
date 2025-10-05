import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hospital_virtuel/screens/patient/full_screen_image_page.dart'; // Importation pour l'image en plein écran
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Importation pour initializeDateFormatting
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:firebase_storage/firebase_storage.dart'; // For uploading to Storage
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'dart:io'; // For File type
import 'dart:math'; // Pour Random
import 'package:hospital_virtuel/screens/settings/settings.dart'; // Ajout pour la page des paramètres

mixin DoctorNameHelper {
  Future<String> getDoctorName(String userId) async {
    try {
      // Récupérer le prénom depuis la collection 'doctors'
      var doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(userId)
          .get();

      if (doctorDoc.exists) {
        final doctorData = doctorDoc.data() as Map<String, dynamic>;
        final prenom = doctorData['Prenom']?.toString();
        
        if (prenom != null && prenom.isNotEmpty) {
          return prenom;
        }
      }

      return 'Auteur inconnu';
    } catch (e) {
      print("Error getting doctor name: $e");
      return 'Auteur inconnu';
    }
  }
}

class ForumPage extends StatefulWidget {
  final bool isDesktop;
  
  const ForumPage({super.key, this.isDesktop = false});

  @override
  _ForumPageState createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> with DoctorNameHelper {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isDescriptionVisible = false;
  bool _isCreatingPost = false;
  XFile? _selectedImageFile;
  bool _isUploadingImage = false;

  // Ajouts pour la recherche
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Listener pour reconstruire la liste lors de la saisie dans la recherche
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _pickImage() async {
    final theme = Theme.of(context);
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() {
          _selectedImageFile = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de l\'image: $e', 
              style: GoogleFonts.roboto(color: theme.colorScheme.onError)
            ), 
            backgroundColor: theme.colorScheme.error
          ),
        );
      }
    }
  }

  void _clearPostCreationForm() {
    _controller.clear();
    _descriptionController.clear();
    setState(() {
      _isDescriptionVisible = false;
      _selectedImageFile = null;
      _isUploadingImage = false; // Important de réinitialiser ici aussi
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _descriptionController.dispose();
    _searchController.dispose(); // Ne pas oublier de disposer le controller de recherche
    super.dispose();
  }

  // Méthode pour construire le champ de recherche dans l'AppBar
  Widget _buildSearchField(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Rechercher par titre ou description...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: theme.colorScheme.onPrimary.withOpacity(0.7)),
      ),
      style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 18.0),
      onChanged: (query) {
        setState(() {}); // Met à jour l'UI à chaque changement
      },
    );
  }

  // Méthode pour construire les actions de l'AppBar en mode recherche
  List<Widget> _buildSearchActions(BuildContext context) {
    final theme = Theme.of(context);
    return [
      IconButton(
        icon: Icon(Icons.close, color: theme.colorScheme.onPrimary),
        onPressed: () {
          if (_searchController.text.isEmpty) {
            setState(() {
              _isSearching = false;
            });
          } else {
            _searchController.clear();
          }
        },
      ),
    ];
  }

  // Méthode pour construire les actions par défaut de l'AppBar
  List<Widget> _buildDefaultActions(BuildContext context) {
    final theme = Theme.of(context);
    return [
      IconButton(
        icon: Icon(_isCreatingPost ? Icons.close_rounded : Icons.add_circle_outline_rounded),
        onPressed: () {
          setState(() {
            _isCreatingPost = !_isCreatingPost;
            if (!_isCreatingPost) {
              _clearPostCreationForm();
            }
          });
        },
        tooltip: _isCreatingPost ? 'Annuler' : 'Nouveau sujet',
        color: theme.colorScheme.onPrimary,
        iconSize: 26,
      ),
      PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'search') {
            setState(() {
              _isSearching = true;
            });
          } else if (value == 'settings') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'search',
            child: ListTile(
              leading: Icon(Icons.search),
              title: Text('Rechercher un sujet'),
            ),
          ),
          const PopupMenuItem<String>(
            value: 'settings',
            child: ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Paramètres'),
            ),
          ),
        ],
        icon: Icon(Icons.more_vert, color: theme.colorScheme.onPrimary),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: widget.isDesktop
          ? null // Pas d'AppBar en mode desktop
          : AppBar(
              systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
              title: _isSearching
                  ? _buildSearchField(context)
                  : Text(
                      'Forum ',
                      style: GoogleFonts.lato(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
              centerTitle: false,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.lightBlue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              elevation: 3.0,
              actions: _isSearching ? _buildSearchActions(context) : _buildDefaultActions(context),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isCreatingPost)
              Flexible( 
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  margin: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 8.0, right: 8.0), 
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16), 
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView( 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        Text(
                          'Créer un nouveau sujet',
                          style: GoogleFonts.lato( 
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary, 
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Titre du sujet...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10), 
                              borderSide: BorderSide(color: theme.dividerColor),
                            ),
                            labelText: 'Titre du sujet',
                            prefixIcon: Icon(Icons.title_rounded, color: theme.colorScheme.primary), 
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                            ),
                          ),
                          onChanged: (text) {
                            setState(() {
                              _isDescriptionVisible = text.isNotEmpty;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_isDescriptionVisible)
                          TextField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              hintText: 'Décrivez le sujet...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10), 
                                borderSide: BorderSide(color: theme.dividerColor),
                              ),
                              labelText: 'Description',
                              prefixIcon: Icon(Icons.description_rounded, color: theme.colorScheme.primary), 
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                              ),
                            ),
                            maxLines: 4,
                          ),
                        const SizedBox(height: 16),
                        if (_selectedImageFile == null)
                          Center(
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.primary), 
                              label: Text('Ajouter une image (optionnel)', style: GoogleFonts.roboto(color: theme.colorScheme.primary, fontWeight: FontWeight.w500)), 
                              onPressed: _pickImage,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), 
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                              ),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Image sélectionnée:', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                              const SizedBox(height: 8),
                              Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: kIsWeb
                                        ? Image.network( 
                                            _selectedImageFile!.path,
                                            height: 150,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file( 
                                            File(_selectedImageFile!.path),
                                            height: 150,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  Container(
                                    margin: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton( 
                                      icon: Icon(Icons.close_rounded, color: theme.colorScheme.onPrimary, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _selectedImageFile = null;
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isUploadingImage ? null : () {
                                setState(() {
                                  _isCreatingPost = false;
                                  _clearPostCreationForm();
                                }); 
                              },
                              child: Text('Annuler', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isUploadingImage ? null : () async {
                                final theme = Theme.of(context);
                                final currentUser = FirebaseAuth.instance.currentUser;
                                final sujetText = _controller.text.trim();
                                final descriptionText = _descriptionController.text.trim();
  
                                if (sujetText.isEmpty) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Le titre du sujet ne peut pas être vide.',
                                          style: GoogleFonts.roboto(color: theme.colorScheme.onError)
                                        ),
                                        backgroundColor: theme.colorScheme.error,
                                      ),
                                    );
                                  }
                                  return;
                                }
  
                                if (currentUser == null) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Utilisateur non authentifié.",
                                          style: GoogleFonts.roboto(color: theme.colorScheme.onError)
                                        ), 
                                        backgroundColor: theme.colorScheme.error
                                      )
                                    );
                                    return;
                                }
  
                                setState(() { _isUploadingImage = true; });
  
                                try {
                                  String? imageUrl;
                                  if (_selectedImageFile != null) {
                                    try {
                                      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedImageFile!.name}';
                                      Reference storageRef = FirebaseStorage.instance.ref().child('forum_images/$fileName');                                      
                                      UploadTask uploadTask;
                                      if (kIsWeb) {
                                        uploadTask = storageRef.putData(await _selectedImageFile!.readAsBytes());
                                      } else {
                                        uploadTask = storageRef.putFile(File(_selectedImageFile!.path));
                                      }
                                      TaskSnapshot snapshot = await uploadTask;
                                      imageUrl = await snapshot.ref.getDownloadURL();
                                    } catch (e) {
                                       if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Erreur lors du téléversement de l\'image: $e',
                                                style: GoogleFonts.roboto(color: theme.colorScheme.onError)
                                              ), 
                                              backgroundColor: theme.colorScheme.error
                                            ),
                                          );
                                          setState(() { _isUploadingImage = false; });
                                        }
                                        return; 
                                    }
                                  }
  
                                  String doctorName = await getDoctorName(currentUser.uid);
  
                                  await FirebaseFirestore.instance.collection('forum').add({
                                    'sujet': sujetText,
                                    'description': descriptionText,
                                    'date_creation': FieldValue.serverTimestamp(),
                                    'userId': currentUser.uid,
                                    'username': doctorName,
                                    'upvotes': 0,
                                    'downvotes': 0,
                                    'upvoters': [],
                                    'downvoters': [],
                                    'imageUrl': imageUrl, // Toujours inclure le champ, il sera null si aucune image
                                  });
                                  
                                  if (mounted) {
                                    setState(() { _isCreatingPost = false; });
                                    _clearPostCreationForm(); 
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Sujet créé avec succès !', 
                                          style: GoogleFonts.roboto(
                                            color: theme.colorScheme.onPrimary,
                                            fontWeight: FontWeight.w500,
                                          )
                                        ),
                                        backgroundColor: theme.colorScheme.primary,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) { 
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Erreur lors de la publication: $e',
                                          style: GoogleFonts.roboto(color: theme.colorScheme.onError)
                                        ), 
                                        backgroundColor: theme.colorScheme.error
                                      ),
                                    );
                                    setState(() { _isUploadingImage = false; });
                                  }
                                }
                              },
                              icon: _isUploadingImage 
                                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2)) 
                                  : const Icon(Icons.check_rounded),
                              label: Text(_isUploadingImage ? 'Publication...' : 'Publier', style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold)), 
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary, 
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('forum')
                    .orderBy('date_creation', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 64, color: theme.colorScheme.error.withOpacity(0.7)), 
                          const SizedBox(height: 16),
                          Text(
                            'Erreur: ${snapshot.error}',
                            style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator( 
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    );
                  }

                  var sujets = snapshot.data!.docs;

                  if (_searchController.text.isNotEmpty) {
                    final query = _searchController.text.toLowerCase();
                    sujets = sujets.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final titre = (data['sujet'] as String? ?? '').toLowerCase();
                      final description =
                          (data['description'] as String? ?? '').toLowerCase();
                      return titre.contains(query) || description.contains(query);
                    }).toList();
                  }

                  if (sujets.isEmpty) {
                    return Center(
                      child: SingleChildScrollView( 
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon( 
                              Icons.forum_outlined,
                              size: 80, 
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun sujet de discussion',
                              style: GoogleFonts.lato(
                                fontSize: 18,
                                color: theme.textTheme.titleMedium?.color, 
                                fontWeight: FontWeight.bold,
                              ), 
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Soyez le premier à créer un sujet !',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: theme.textTheme.bodySmall?.color,
                              ), 
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon( 
                              onPressed: () {
                              setState(() {
                                _isCreatingPost = true;
                              });
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: Text('Créer un sujet', style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold)), 
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16), 
                    itemCount: sujets.length,
                    itemBuilder: (context, index) {
                      var sujet = sujets[index].data() as Map<String, dynamic>;
                      String sujetId = sujets[index].id;
                      Timestamp? timestamp = sujet['date_creation'] as Timestamp?;
                      String formattedTime = timestamp != null
                          ? DateFormat('dd/MM/yyyy').format(timestamp.toDate())
                          : '';
                      String description = sujet['description'] ?? '';
                      int upvotes = sujet['upvotes'] ?? 0;
                      List<dynamic> upvoters = List.from(sujet['upvoters'] ?? []); 
                      int downvotes = sujet['downvotes'] ?? 0;
                      List<dynamic> downvoters = List.from(sujet['downvoters'] ?? []); 
                      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
                      String? imageUrl = sujet['imageUrl'] as String?;

                      Color? cardBackgroundColor;
                      Color cardTextColor = theme.textTheme.bodyLarge?.color ?? Colors.black87; 
                      TextStyle authorDateStyle = GoogleFonts.roboto(fontSize: 12, color: theme.textTheme.bodySmall?.color);
                      TextStyle descriptionStyle = GoogleFonts.roboto(fontSize: 14, color: theme.textTheme.bodyMedium?.color, height: 1.4);

                      if (imageUrl == null) {
                        final int hash = sujetId.hashCode;
                        final random = Random(hash); 
                        cardBackgroundColor = Colors.primaries[random.nextInt(Colors.primaries.length)].withOpacity(0.1); 
                        
                        if (ThemeData.estimateBrightnessForColor(cardBackgroundColor) == Brightness.dark) {
                          cardTextColor = Colors.white.withOpacity(0.9);
                          authorDateStyle = GoogleFonts.roboto(fontSize: 12, color: Colors.white.withOpacity(0.7));
                          descriptionStyle = GoogleFonts.roboto(fontSize: 14, color: Colors.white.withOpacity(0.85), height: 1.4);
                        }
                      }

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 16), 
                        shape: RoundedRectangleBorder( 
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: cardBackgroundColor ?? theme.cardColor,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SujetDetailsPage(sujetId: sujetId),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column( 
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column( 
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sujet['sujet'],
                                            style: GoogleFonts.lato( 
                                              fontSize: 18, 
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[600],
                                           ), 
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${sujet['username'] ?? 'Utilisateur inconnu'} • $formattedTime',
                                            style: authorDateStyle,
                                          ),
                                        ],
                                ),
                                const SizedBox(height: 12), 
                                if (imageUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0, bottom: 8.0), 
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FullScreenImagePage(
                                              imageProvider: NetworkImage(imageUrl),
                                              tag: 'forum_image_$sujetId', 
                                            ),
                                          ),
                                        );
                                      },
                                      child: Hero(
                                        tag: 'forum_image_$sujetId',
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12.0),
                                          child: Image.network(
                                            imageUrl,
                                            height: 180,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return SizedBox(
                                                height: 180,
                                                child: Center( 
                                                  child: CircularProgressIndicator(
                                                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                        : null,
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                height: 180, 
                                                color: theme.colorScheme.surfaceVariant,
                                                child: Center(child: Icon(Icons.broken_image_rounded, color: theme.textTheme.bodySmall?.color?.withOpacity(0.5), size: 40)),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(height: 12),
                                if (description.isNotEmpty)
                                  Text(
                                    description,
                                    style: descriptionStyle,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        _buildVoteButton( 
                                          icon: Icons.thumb_up_alt_outlined,
                                          count: upvotes,
                                          isActive: upvoters.contains(userId),
                                          activeColor: theme.colorScheme.primary,
                                          onPressed: () async {
                                            try {
                                              DocumentReference sujetRef = FirebaseFirestore.instance.collection('forum').doc(sujetId);
                                              if (!upvoters.contains(userId)) {
                                                WriteBatch batch = FirebaseFirestore.instance.batch();
                                                if (downvoters.contains(userId)) {
                                                  batch.update(sujetRef, {
                                                    'downvotes': FieldValue.increment(-1),
                                                    'downvoters': FieldValue.arrayRemove([userId]),
                                                  });
                                                }
                                                batch.update(sujetRef, {
                                                  'upvotes': FieldValue.increment(1),
                                                  'upvoters': FieldValue.arrayUnion([userId]),
                                                });
                                                await batch.commit();
                                              } else {
                                                await sujetRef.update({
                                                  'upvotes': FieldValue.increment(-1),
                                                  'upvoters': FieldValue.arrayRemove([userId]),
                                                });
                                              }
                                            } catch (e) {
                                              print("Error upvoting subject in ForumPage: $e");
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Erreur lors du vote: ${e.toString()}',
                                                      style: GoogleFonts.roboto(color: theme.colorScheme.onError)
                                                    ),
                                                    backgroundColor: theme.colorScheme.error,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        _buildVoteButton( 
                                          icon: Icons.thumb_down_alt_outlined,
                                          count: downvotes,
                                          isActive: downvoters.contains(userId),
                                          activeColor: theme.colorScheme.error,
                                          onPressed: () async {
                                            try {
                                              DocumentReference sujetRef = FirebaseFirestore.instance.collection('forum').doc(sujetId);
                                              if (!downvoters.contains(userId)) {
                                                WriteBatch batch = FirebaseFirestore.instance.batch();
                                                if (upvoters.contains(userId)) {
                                                   batch.update(sujetRef, {
                                                    'upvotes': FieldValue.increment(-1),
                                                    'upvoters': FieldValue.arrayRemove([userId]),
                                                  });
                                                }
                                                batch.update(sujetRef, {
                                                  'downvotes': FieldValue.increment(1),
                                                  'downvoters': FieldValue.arrayUnion([userId]),
                                                });
                                                await batch.commit();
                                              } else {
                                                await sujetRef.update({
                                                  'downvotes': FieldValue.increment(-1),
                                                  'downvoters': FieldValue.arrayRemove([userId]),
                                                });
                                              }
                                            } catch (e) {
                                              print("Error downvoting subject in ForumPage: $e");
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Erreur lors du vote: ${e.toString()}',
                                                      style: GoogleFonts.roboto(color: theme.colorScheme.onError)
                                                    ),
                                                    backgroundColor: theme.colorScheme.error,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (userId == sujet['userId'])
                                          IconButton( 
                                            icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                                            onPressed: () async {
                                              bool? confirmDelete = await showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text('Confirmation de suppression'),
                                                    content: const Text('Êtes-vous sûr de vouloir supprimer ce sujet ?'),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    actions: <Widget>[
                                                      TextButton(
                                                        child: const Text('Annuler'),
                                                        onPressed: () {
                                                          Navigator.of(context).pop(false);
                                                        },
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: theme.colorScheme.error,
                                                          foregroundColor: Colors.white,
                                                        ),
                                                        onPressed: () {
                                                          Navigator.of(context).pop(true);
                                                        },
                                                        child: const Text('Supprimer'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );

                                              if (confirmDelete == true) {
                                                await FirebaseFirestore.instance.collection('forum').doc(sujetId).delete();
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Sujet supprimé avec succès',
                                                        style: GoogleFonts.roboto(
                                                          color: theme.colorScheme.onPrimary,
                                                          fontWeight: FontWeight.w500,
                                                        )
                                                      ),
                                                      backgroundColor: theme.colorScheme.primary,
                                                      behavior: SnackBarBehavior.floating,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.comment_outlined, size: 20), 
                                          label: const Text('Commenter'),
                                          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => SujetDetailsPage(sujetId: sujetId),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Widget _buildVoteButton({
    required IconData icon,
    required int count,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.7) : theme.dividerColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18, 
              color: isActive ? activeColor : theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: GoogleFonts.roboto(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? activeColor : theme.textTheme.bodySmall?.color, 
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class SujetDetailsPage extends StatefulWidget {
  final String sujetId;

  const SujetDetailsPage({super.key, required this.sujetId});

  @override
  _SujetDetailsPageState createState() => _SujetDetailsPageState();
}

class _SujetDetailsPageState extends State<SujetDetailsPage> with DoctorNameHelper {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  String? _replyingToCommentId;
  String? _replyingToUsername;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _confirmDeletion(String commentaireId) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirmer la suppression', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          content: Text('Êtes-vous sûr de vouloir supprimer ce commentaire ?', style: GoogleFonts.roboto()),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler', style: GoogleFonts.roboto(color: Colors.grey.shade700)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text('Supprimer', style: GoogleFonts.roboto()),
            ),
          ],
        );
      },
    );

    if (confirm == true) { 
      await FirebaseFirestore.instance
          .collection('forum')
          .doc(widget.sujetId)
          .collection('commentaires')
          .doc(commentaireId)
          .delete();
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commentaire supprimé avec succès', 
              style: GoogleFonts.roboto(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
              )
            ),
            backgroundColor: theme.colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[100], 
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2.0, 
        title: Text(
          'Détails du Sujet',
          style: GoogleFonts.lato(
            color: Colors.black87, 
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black87), 
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('forum')
            .doc(widget.sujetId)
            .snapshots(),
        builder: (context, sujetSnapshot) {
          if (sujetSnapshot.hasError) {
            return Center(child: Text('Erreur: ${sujetSnapshot.error}', style: GoogleFonts.roboto()));
          }
          if (sujetSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent)));
          }

          if (!sujetSnapshot.hasData || !sujetSnapshot.data!.exists) { 
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Sujet non trouvé',
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ce sujet a peut-être été supprimé ou n\'existe plus.',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: Icon(Icons.arrow_back_ios_new_rounded),
                    label: Text("Retour au forum", style: GoogleFonts.roboto()),
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                    ),
                  )
                ],
              ),
            );
          }

          var sujetData = sujetSnapshot.data!.data() as Map<String, dynamic>;
          Timestamp? timestamp = sujetData['date_creation'] as Timestamp?;
          String formattedTime = timestamp != null
              ? DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(timestamp.toDate()) 
              : '';
          String? imageUrl = sujetData['imageUrl'] as String?;
          
          return Column( 
            children: [
              Expanded( 
                child: SingleChildScrollView(
                  child: Column(
                    children: [ 
                      Container( 
                        padding: const EdgeInsets.all(16.0),
                        margin: const EdgeInsets.all(12.0), 
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0), 
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.15),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row( 
                              children: [ 
                                CircleAvatar(
                                  backgroundColor: Colors.blueAccent.withOpacity(0.8),
                                  radius: 22,
                                  child: Text(
                                    sujetData['username'] != null && (sujetData['username'] as String).isNotEmpty 
                                      ? (sujetData['username'] as String).substring(0, 1).toUpperCase() 
                                      : '?',
                                    style: GoogleFonts.lato(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sujetData['sujet'],
                                        style: GoogleFonts.lato( 
                                          fontSize: 20, 
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Par ${sujetData['username'] ?? 'Utilisateur inconnu'} • $formattedTime',
                                        style: GoogleFonts.roboto(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (imageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0), 
                                child: GestureDetector( 
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FullScreenImagePage(
                                          imageProvider: NetworkImage(imageUrl),
                                          tag: 'sujet_image_details_${widget.sujetId}', 
                                        ),
                                      ),
                                    );
                                  },
                                  child: Hero(
                                    tag: 'sujet_image_details_${widget.sujetId}',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12.0),
                                      child: Stack(
                                        children: [
                                          Image.network(
                                            imageUrl,
                                            height: 220, 
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return SizedBox(
                                                height: 220,
                                                child: Center( 
                                                  child: CircularProgressIndicator(
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                        : null,
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                height: 220, 
                                                color: Colors.grey[200],
                                                child: Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey[400], size: 50)),
                                              );
                                            },
                                          ),
                                          // Description en bas de l'image
                                          if (sujetData['description'] != null && (sujetData['description'] as String).isNotEmpty)
                                            Positioned(
                                              bottom: 0,
                                              left: 0,
                                              right: 0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.black.withOpacity(0.8),
                                                    ],
                                                  ),
                                                  borderRadius: const BorderRadius.only(
                                                    bottomLeft: Radius.circular(12),
                                                    bottomRight: Radius.circular(12),
                                                  ),
                                                ),
                                                padding: const EdgeInsets.all(12.0),
                                                child: _buildImageDescriptionPreview(sujetData['description'], sujetData['sujet'] ?? 'Sujet du forum'),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ) else ...[
                              const SizedBox(height: 16),
                            if (sujetData['description'] != null && (sujetData['description'] as String).isNotEmpty)
                              _buildDescriptionPreview(sujetData['description'], sujetData['sujet'] ?? 'Sujet du forum')
                            else 
                              Text(
                                'Pas de description fournie pour ce sujet.',
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row( 
                                  children: [
                                    _buildVoteButton(
                                      icon: Icons.thumb_up_alt_outlined,
                                      count: sujetData['upvotes'] ?? 0,
                                      isActive: (sujetData['upvoters'] as List<dynamic>?)?.contains(FirebaseAuth.instance.currentUser?.uid) ?? false,
                                      activeColor: Colors.blue.shade600,
                                      onPressed: () async {
                                        final theme = Theme.of(context);
                                        String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
                                        if (userId.isEmpty) return;
                                        List<dynamic> upvoters = List.from(sujetData['upvoters'] ?? []);
                                        List<dynamic> downvoters = List.from(sujetData['downvoters'] ?? []);
                                        
                                        DocumentReference sujetRef = FirebaseFirestore.instance.collection('forum').doc(widget.sujetId);
                                        try {
                                          if (!upvoters.contains(userId)) {
                                            WriteBatch batch = FirebaseFirestore.instance.batch();
                                            if (downvoters.contains(userId)) {
                                              batch.update(sujetRef, {
                                                'downvotes': FieldValue.increment(-1),
                                                'downvoters': FieldValue.arrayRemove([userId]),
                                              });
                                            }
                                            batch.update(sujetRef, {
                                              'upvotes': FieldValue.increment(1),
                                              'upvoters': FieldValue.arrayUnion([userId]),
                                            });
                                            await batch.commit();
                                          } else {
                                            await sujetRef.update({
                                              'upvotes': FieldValue.increment(-1),
                                              'upvoters': FieldValue.arrayRemove([userId]),
                                            });
                                          }
                                        } catch (e) {
                                          print("Error upvoting subject in SujetDetailsPage: $e");
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Erreur de vote (sujet): ${e.toString()}', 
                                                  style: GoogleFonts.roboto(color: theme.colorScheme.onError)
                                                ),
                                                backgroundColor: theme.colorScheme.error,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    _buildVoteButton(
                                      icon: Icons.thumb_down_alt_outlined,
                                      count: sujetData['downvotes'] ?? 0,
                                      isActive: (sujetData['downvoters'] as List<dynamic>?)?.contains(FirebaseAuth.instance.currentUser?.uid) ?? false,
                                      activeColor: Colors.red.shade600,
                                      onPressed: () async {
                                        final theme = Theme.of(context);
                                        String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
                                        if (userId.isEmpty) return;
                                        List<dynamic> upvoters = List.from(sujetData['upvoters'] ?? []);
                                        List<dynamic> downvoters = List.from(sujetData['downvoters'] ?? []);
                                        
                                        DocumentReference sujetRef = FirebaseFirestore.instance.collection('forum').doc(widget.sujetId);
                                        try {
                                          if (!downvoters.contains(userId)) {
                                             WriteBatch batch = FirebaseFirestore.instance.batch();
                                            if (upvoters.contains(userId)) {
                                              batch.update(sujetRef, {
                                                'upvotes': FieldValue.increment(-1),
                                                'upvoters': FieldValue.arrayRemove([userId]),
                                              });
                                            }
                                            batch.update(sujetRef, {
                                              'downvotes': FieldValue.increment(1),
                                              'downvoters': FieldValue.arrayUnion([userId]),
                                            });
                                            await batch.commit();
                                          } else {
                                            await sujetRef.update({
                                              'downvotes': FieldValue.increment(-1),
                                              'downvoters': FieldValue.arrayRemove([userId]),
                                            });
                                          }
                                        } catch (e) {
                                          print("Error downvoting subject in SujetDetailsPage: $e");
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Erreur de vote (sujet): ${e.toString()}', 
                                                  style: GoogleFonts.roboto(color: theme.colorScheme.onError)
                                                ),
                                                backgroundColor: theme.colorScheme.error,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                if (FirebaseAuth.instance.currentUser?.uid == sujetData['userId'])
                                  IconButton( 
                                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                                    tooltip: "Supprimer le sujet",
                                    onPressed: () async {
                                      bool? confirmDelete = await showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: Text('Confirmation de suppression', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                                            content: Text('Êtes-vous sûr de vouloir supprimer ce sujet et tous ses commentaires ?', style: GoogleFonts.roboto()),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                child: Text('Annuler', style: GoogleFonts.roboto(color: Colors.grey.shade700)),
                                                onPressed: () {
                                                  Navigator.of(context).pop(false);
                                                },
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                                ),
                                                onPressed: () {
                                                  Navigator.of(context).pop(true);
                                                },
                                                child: Text('Supprimer', style: GoogleFonts.roboto()),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (confirmDelete == true) {
                                        await FirebaseFirestore.instance.collection('forum').doc(widget.sujetId).delete();
                                        if (mounted) {
                                          Navigator.pop(context); 
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Sujet supprimé avec succès', 
                                                style: GoogleFonts.roboto(
                                                  color: theme.colorScheme.onPrimary,
                                                  fontWeight: FontWeight.w500,
                                                )
                                              ),
                                              backgroundColor: theme.colorScheme.primary,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding( 
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 8.0),
                        child: Text(
                          "Commentaires",
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('forum')
                            .doc(widget.sujetId) 
                            .collection('commentaires')
                            .orderBy('createdAt', descending: false) 
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Erreur de chargement des commentaires: ${snapshot.error}', style: GoogleFonts.roboto()));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding( 
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent))),
                            );
                          }

                          var commentaires = snapshot.data!.docs;

                          if (commentaires.isEmpty) {
                            return Padding( 
                              padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
                              child: Center( 
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.comment_bank_outlined, 
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Aucun commentaire pour l\'instant',
                                      style: GoogleFonts.lato(
                                        fontSize: 17,
                                        color: Colors.grey.shade600, 
                                        fontWeight: FontWeight.w600,
                                      ), 
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Soyez le premier à partager votre avis !',
                                      style: GoogleFonts.roboto(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ), 
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16, top: 8), 
                            itemCount: commentaires.length, 
                            shrinkWrap: true, 
                            physics: const NeverScrollableScrollPhysics(), 
                            itemBuilder: (context, index) {
                              var commentaire = commentaires[index].data() as Map<String, dynamic>;
                              String commentaireId = commentaires[index].id;
                              Timestamp? commentTimestamp = commentaire['createdAt'] as Timestamp?; 
                              String formattedCommentTime = commentTimestamp != null
                                  ? DateFormat('dd/MM/yy HH:mm', 'fr_FR').format(commentTimestamp.toDate())
                                  : '';
                              int upvotes = commentaire['upvotes'] ?? 0;
                              List<dynamic> upvoters = List.from(commentaire['upvoters'] ?? []);
                              int downvotes = commentaire['downvotes'] ?? 0;
                              List<dynamic> downvoters = List.from(commentaire['downvoters'] ?? []);
                              String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                              String? repliedToUsername = commentaire['replyToUsername'] as String?;

                              return Card(
                                elevation: 1.5, 
                                margin: const EdgeInsets.only(bottom: 12), 
                                shape: RoundedRectangleBorder( 
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row( 
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [ 
                                          CircleAvatar(
                                            backgroundColor: Colors.grey.shade300,
                                            radius: 18, 
                                            child: Text(
                                              commentaire['username'] != null && (commentaire['username'] as String).isNotEmpty 
                                                ? (commentaire['username'] as String).substring(0, 1).toUpperCase() 
                                                : '?',
                                              style: GoogleFonts.lato(
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  commentaire['username'] ?? 'Utilisateur inconnu',
                                                  style: GoogleFonts.roboto( 
                                                    fontWeight: FontWeight.w600, 
                                                    fontSize: 14.5,
                                                    color: Colors.black87
                                                  ), 
                                                ),
                                                Text(
                                                  formattedCommentTime,
                                                  style: GoogleFonts.roboto(
                                                    fontSize: 11.5,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (currentUserId == commentaire['userId'])
                                            IconButton( 
                                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                              tooltip: "Supprimer le commentaire",
                                              padding: EdgeInsets.zero, 
                                              constraints: BoxConstraints(), 
                                              onPressed: () async {
                                                await _confirmDeletion(commentaireId);
                                              },
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (repliedToUsername != null && repliedToUsername.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6.0, left: 4.0), 
                                          child: RichText(
                                            text: TextSpan(
                                              style: GoogleFonts.roboto(
                                                fontSize: 12.5, 
                                                color: Colors.grey.shade600, 
                                              ),
                                              children: <TextSpan>[ 
                                                TextSpan(text: '↪ En réponse à '),
                                                TextSpan(
                                                  text: '@$repliedToUsername',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600, 
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      Padding( 
                                        padding: const EdgeInsets.only(left: 4.0, right: 4.0),
                                        child: Text(
                                          commentaire['text'], 
                                          style: GoogleFonts.roboto( 
                                            fontSize: 14.5,
                                            color: Colors.black.withOpacity(0.75),
                                            height: 1.4, 
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12), 
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.start, 
                                        children: [
                                          _buildVoteButton(
                                            icon: Icons.thumb_up_alt_outlined, 
                                            count: upvotes,
                                            isActive: upvoters.contains(currentUserId),
                                            activeColor: Colors.blue.shade600,
                                            onPressed: () async {
                                              final theme = Theme.of(context);
                                              if (currentUserId.isEmpty) return;
                                              DocumentReference commentRef = FirebaseFirestore.instance
                                                .collection('forum').doc(widget.sujetId)
                                                .collection('commentaires').doc(commentaireId);
                                              try {
                                                if (!upvoters.contains(currentUserId)) {
                                                  WriteBatch batch = FirebaseFirestore.instance.batch();
                                                  if (downvoters.contains(currentUserId)) {
                                                     batch.update(commentRef, {
                                                      'downvotes': FieldValue.increment(-1),
                                                      'downvoters': FieldValue.arrayRemove([currentUserId]),
                                                    });
                                                  }
                                                  batch.update(commentRef, {
                                                    'upvotes': FieldValue.increment(1),
                                                    'upvoters': FieldValue.arrayUnion([currentUserId]),
                                                  });
                                                  await batch.commit();
                                                } else {
                                                  await commentRef.update({
                                                    'upvotes': FieldValue.increment(-1),
                                                    'upvoters': FieldValue.arrayRemove([currentUserId]),
                                                  });
                                                }
                                              } catch (e) {
                                                print("Error upvoting comment: $e");
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Erreur de vote (commentaire): ${e.toString()}', 
                                                        style: GoogleFonts.roboto(color: theme.colorScheme.onError)
                                                      ),
                                                      backgroundColor: theme.colorScheme.error,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 10),
                                          _buildVoteButton( 
                                            icon: Icons.thumb_down_alt_outlined,
                                            count: downvotes,
                                            isActive: downvoters.contains(currentUserId),
                                            activeColor: Colors.red.shade600,
                                            onPressed: () async {
                                              final theme = Theme.of(context);
                                              if (currentUserId.isEmpty) return;
                                               DocumentReference commentRef = FirebaseFirestore.instance
                                                .collection('forum').doc(widget.sujetId)
                                                .collection('commentaires').doc(commentaireId);
                                              try {
                                                if (!downvoters.contains(currentUserId)) {
                                                  WriteBatch batch = FirebaseFirestore.instance.batch();
                                                  if (upvoters.contains(currentUserId)) {
                                                    batch.update(commentRef, {
                                                      'upvotes': FieldValue.increment(-1),
                                                      'upvoters': FieldValue.arrayRemove([currentUserId]),
                                                    });
                                                  }
                                                  batch.update(commentRef, {
                                                    'downvotes': FieldValue.increment(1),
                                                    'downvoters': FieldValue.arrayUnion([currentUserId]),
                                                  });
                                                  await batch.commit();
                                                } else {
                                                  await commentRef.update({
                                                    'downvotes': FieldValue.increment(-1),
                                                    'downvoters': FieldValue.arrayRemove([currentUserId]),
                                                  });
                                                }
                                              } catch (e) {
                                                print("Error downvoting comment: $e");
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Erreur de vote (commentaire): ${e.toString()}', 
                                                        style: GoogleFonts.roboto(color: theme.colorScheme.onError)
                                                      ),
                                                      backgroundColor: theme.colorScheme.error,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 16),
                                          TextButton.icon(
                                            icon: Icon(Icons.reply_rounded, size: 18, color: Colors.grey.shade700), 
                                            label: Text('Répondre', style: GoogleFonts.roboto(fontSize: 12.5, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: Size(0,0),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)) 
                                            ),
                                            onPressed: () {
                                              String? usernameToReply = commentaire['username'] as String?;
                                              if (usernameToReply == null || usernameToReply.trim().isEmpty) {
                                                usernameToReply = "Utilisateur inconnu";
                                              }
                                              setState(() {
                                                _replyingToCommentId = commentaireId;
                                                _replyingToUsername = usernameToReply;
                                              });
                                              _commentFocusNode.requestFocus();
                                            },
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
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), 
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingToUsername != null && _replyingToUsername!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, right: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible( 
                              child: Text( 
                                'En réponse à @$_replyingToUsername',
                                style: GoogleFonts.roboto(color: Colors.blue.shade700, fontStyle: FontStyle.italic, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey[600]),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                              tooltip: 'Annuler la réponse',
                              onPressed: () {
                                setState(() {
                                  _replyingToCommentId = null;
                                  _replyingToUsername = null;
                                });
                              },
                            )
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center, 
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController, 
                            focusNode: _commentFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Écrire un commentaire...',
                              hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0), 
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder( 
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0), 
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), 
                              prefixIcon: Padding( 
                                padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                                child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.blue.shade600.withOpacity(0.8), size: 22),
                              ),
                              filled: true, 
                              fillColor: Colors.grey.shade50.withOpacity(0.7), 
                            ),
                            onSubmitted: (_) => _submitComment(),
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 4, 
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.blue.shade600, 
                          borderRadius: BorderRadius.circular(25),
                          elevation: 2.0, 
                          child: InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: _submitComment,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0), 
                              child: Icon(Icons.send_rounded, color: Colors.white, size: 24), 
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ); 
        },
      ),
    );
  }

  void _submitComment() async {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final commentaireText = _commentController.text.trim();

    if (commentaireText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Le commentaire ne peut pas être vide.', 
              style: GoogleFonts.roboto(color: theme.colorScheme.onError)
            ), 
            backgroundColor: theme.colorScheme.error
          ),
        );
      }
      return;
    }

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Utilisateur non connecté. Veuillez vous reconnecter.', 
              style: GoogleFonts.roboto(color: theme.colorScheme.onError)
            ), 
            backgroundColor: theme.colorScheme.error
          ),
        );
      }
      return;
    }

    try {
      String doctorName = await getDoctorName(currentUser.uid);

      Map<String, dynamic> commentData = {
        'text': commentaireText, 
        'createdAt': FieldValue.serverTimestamp(), 
        'userId': currentUser.uid,
        'username': doctorName,
        'upvotes': 0,
        'upvoters': [],
        'downvotes': 0,
        'downvoters': [],
      };

      if (_replyingToCommentId != null && _replyingToUsername != null) {
        commentData['replyToCommentId'] = _replyingToCommentId;
        commentData['replyToUsername'] = _replyingToUsername;
      }

      await FirebaseFirestore.instance
          .collection('forum')
          .doc(widget.sujetId)
          .collection('commentaires')
          .add(commentData);

      _commentController.clear();
      if (mounted) { 
        setState(() {
          _replyingToCommentId = null;
          _replyingToUsername = null;
        });
        _commentFocusNode.unfocus(); 
      }
    } catch (e) {
      print('Erreur lors de l\'ajout du commentaire: $e');
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi du commentaire: ${e.toString()}', 
              style: GoogleFonts.roboto(color: theme.colorScheme.onError)
            ), 
            backgroundColor: theme.colorScheme.error
          ),
        );
      }
    }
  }

  Widget _buildDescriptionPreview(String description, String sujetTitre) {
    // Limite le texte à environ 3 lignes (150 caractères)
    const int maxLength = 150;
    final bool isLongText = description.length > maxLength;
    final String displayText = isLongText 
        ? '${description.substring(0, maxLength)}...' 
        : description;
    
    return GestureDetector(
      onTap: () {
        if (isLongText) {
          _showFullDescriptionDialog(description, sujetTitre);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayText,
              style: GoogleFonts.roboto(
                fontSize: 15.5,
                color: Colors.grey[850],
                height: 1.5,
              ),
            ),
            if (isLongText) ...[
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Appuyer pour lire la suite',
                    style: GoogleFonts.roboto(
                      fontSize: 12.0,
                      color: Colors.blue[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12.0,
                    color: Colors.blue[600],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageDescriptionPreview(String description, String sujetTitre) {
    // Limite le texte à environ 2 lignes (100 caractères) pour l'image
    const int maxLength = 100;
    final bool isLongText = description.length > maxLength;
    final String displayText = isLongText 
        ? '${description.substring(0, maxLength)}...' 
        : description;
    
    return GestureDetector(
      onTap: () {
        _showFullDescriptionDialog(description, sujetTitre);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayText,
            style: GoogleFonts.roboto(
              fontSize: 14.0,
              color: Colors.white,
              height: 1.4,
              shadows: [
                Shadow(
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
          if (isLongText) ...[
            const SizedBox(height: 4.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Appuyer pour lire la suite',
                  style: GoogleFonts.roboto(
                    fontSize: 11.0,
                    color: Colors.white.withOpacity(0.9),
                    fontStyle: FontStyle.italic,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4.0),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 10.0,
                  color: Colors.white.withOpacity(0.9),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showFullDescriptionDialog(String description, String sujetTitre) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête du dialog avec le titre du sujet
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16.0),
                      topRight: Radius.circular(16.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.description, color: Colors.blue[700]),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          sujetTitre,
                          style: GoogleFonts.roboto(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Contenu scrollable
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildMarkdownDescription(description),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarkdownDescription(String description) {
    final lines = description.split('\n');
    final List<Widget> widgets = [];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (line.startsWith('# ')) {
        // Titre principal (H1)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              line.substring(2),
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        // Titre secondaire (H2)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
            child: Text(
              line.substring(3),
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        // Titre tertiaire (H3)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 6.0),
            child: Text(
              line.substring(4),
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ),
        );
      } else if (line.startsWith('**') && line.endsWith('**')) {
        // Texte en gras
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              line.substring(2, line.length - 2),
              style: GoogleFonts.roboto(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        );
      } else if (line.startsWith('*') && line.endsWith('*') && !line.startsWith('**')) {
        // Texte en italique
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              line.substring(1, line.length - 1),
              style: GoogleFonts.roboto(
                fontSize: 15.5,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        // Liste à puces
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: GoogleFonts.roboto(
                    fontSize: 15.5,
                    color: Colors.black87,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.substring(2),
                    style: GoogleFonts.roboto(
                      fontSize: 15.5,
                      color: Colors.grey[850],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.trim().isEmpty) {
        // Ligne vide
        widgets.add(const SizedBox(height: 8.0));
      } else {
        // Texte normal
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              line,
              style: GoogleFonts.roboto(
                fontSize: 15.5,
                color: Colors.grey[850],
                height: 1.5,
              ),
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildVoteButton({
    required IconData icon,
    required int count,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.7) : theme.dividerColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18, 
              color: isActive ? activeColor : theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: GoogleFonts.roboto(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? activeColor : theme.textTheme.bodySmall?.color, 
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
