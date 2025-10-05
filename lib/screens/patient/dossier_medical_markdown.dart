import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class DossierMedicalMarkdownPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const DossierMedicalMarkdownPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  _DossierMedicalMarkdownPageState createState() => _DossierMedicalMarkdownPageState();
}

class _DossierMedicalMarkdownPageState extends State<DossierMedicalMarkdownPage> {
  final _auth = FirebaseAuth.instance;
  bool _isEditing = false;
  String _markdownContent = '';
  Map<String, dynamic>? _userData;
  final Map<String, TextEditingController> _controllers = {};
  final _formKey = GlobalKey<FormState>();
  final List<String> nonOtherInfoEditableKeys = const [
      'first_name', 'last_name', 'name', 'age', 'gender', 'dob', 'bloodGroup', 'blood_type',
      'weight', 'height', 'handicap', 'allergies',
      'phone', 'house_number', 'avenue', 'district', 'city', 'province', 'country',
      'lastSubmitted', 'role', 'email', 'fcmToken', 'medical_notes', 'createdAt', 'prenom', 'nom', 'postnom', 'dateNaissance', 'sexe', 'groupeSanguin', 'antecedentsMedicaux', 'telephone'
    ];

  @override
  void initState() {
    super.initState();
    // Initialisation des contrôleurs se fera dans le StreamBuilder pour avoir les données
  }

  Future<void> _loadAdditionalData() async {
    try {
      List<QueryDocumentSnapshot> feelingsDocs = [];
      List<QueryDocumentSnapshot> consultationsDocs = [];
      List<QueryDocumentSnapshot> rendezvousDocs = [];

      // Charger les feelings (symptômes) - sans orderBy pour éviter l'index
      try {
      QuerySnapshot feelingsSnapshot = await FirebaseFirestore.instance
          .collection('feelings')
          .where('patientId', isEqualTo: widget.patientId)
          .get();
        feelingsDocs = feelingsSnapshot.docs;
        // Trier manuellement par timestamp
        feelingsDocs.sort((a, b) {
          var aTime = a.data() as Map<String, dynamic>;
          var bTime = b.data() as Map<String, dynamic>;
          var aTimestamp = aTime['timestamp'] as Timestamp?;
          var bTimestamp = bTime['timestamp'] as Timestamp?;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.compareTo(aTimestamp); // Descendant
        });
      } catch (e) {
        print('Erreur lors du chargement des feelings: $e');
        // Essayer une requête plus simple sans filtre
        try {
          QuerySnapshot allFeelings = await FirebaseFirestore.instance
              .collection('feelings')
              .get();
          feelingsDocs = allFeelings.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data['patientId'] == widget.patientId;
          }).toList();
          // Trier manuellement
          feelingsDocs.sort((a, b) {
            var aTime = a.data() as Map<String, dynamic>;
            var bTime = b.data() as Map<String, dynamic>;
            var aTimestamp = aTime['timestamp'] as Timestamp?;
            var bTimestamp = bTime['timestamp'] as Timestamp?;
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;
            return bTimestamp.compareTo(aTimestamp);
          });
        } catch (e2) {
          print('Erreur lors du chargement alternatif des feelings: $e2');
        }
      }

      // Charger les consultations à domicile - sans orderBy pour éviter l'index
      try {
      QuerySnapshot consultationsSnapshot = await FirebaseFirestore.instance
          .collection('home_consultations')
          .where('userId', isEqualTo: widget.patientId)
          .get();
        consultationsDocs = consultationsSnapshot.docs;
        // Trier manuellement par timestamp
        consultationsDocs.sort((a, b) {
          var aTime = a.data() as Map<String, dynamic>;
          var bTime = b.data() as Map<String, dynamic>;
          var aTimestamp = aTime['timestamp'] as Timestamp?;
          var bTimestamp = bTime['timestamp'] as Timestamp?;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.compareTo(aTimestamp); // Descendant
        });
      } catch (e) {
        print('Erreur lors du chargement des consultations: $e');
        // Essayer une requête plus simple sans filtre
        try {
          QuerySnapshot allConsultations = await FirebaseFirestore.instance
              .collection('home_consultations')
              .get();
          consultationsDocs = allConsultations.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data['userId'] == widget.patientId;
          }).toList();
          // Trier manuellement
          consultationsDocs.sort((a, b) {
            var aTime = a.data() as Map<String, dynamic>;
            var bTime = b.data() as Map<String, dynamic>;
            var aTimestamp = aTime['timestamp'] as Timestamp?;
            var bTimestamp = bTime['timestamp'] as Timestamp?;
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;
            return bTimestamp.compareTo(aTimestamp);
          });
        } catch (e2) {
          print('Erreur lors du chargement alternatif des consultations: $e2');
        }
      }

      // Charger les rendez-vous - sans orderBy pour éviter l'index
      try {
      QuerySnapshot rendezvousSnapshot = await FirebaseFirestore.instance
          .collection('rendezvous')
          .where('userId', isEqualTo: widget.patientId)
          .get();
        rendezvousDocs = rendezvousSnapshot.docs;
        // Trier manuellement par timestamp
        rendezvousDocs.sort((a, b) {
          var aTime = a.data() as Map<String, dynamic>;
          var bTime = b.data() as Map<String, dynamic>;
          var aTimestamp = aTime['timestamp'] as Timestamp?;
          var bTimestamp = bTime['timestamp'] as Timestamp?;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.compareTo(aTimestamp); // Descendant
        });
      } catch (e) {
        print('Erreur lors du chargement des rendez-vous: $e');
        // Essayer une requête plus simple sans filtre
        try {
          QuerySnapshot allRendezVous = await FirebaseFirestore.instance
              .collection('rendezvous')
              .get();
          rendezvousDocs = allRendezVous.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data['userId'] == widget.patientId;
          }).toList();
          // Trier manuellement
          rendezvousDocs.sort((a, b) {
            var aTime = a.data() as Map<String, dynamic>;
            var bTime = b.data() as Map<String, dynamic>;
            var aTimestamp = aTime['timestamp'] as Timestamp?;
            var bTimestamp = bTime['timestamp'] as Timestamp?;
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;
            return bTimestamp.compareTo(aTimestamp);
          });
        } catch (e2) {
          print('Erreur lors du chargement alternatif des rendez-vous: $e2');
        }
      }

      // Générer le contenu markdown
      _markdownContent = _generateMarkdownContent(
        _userData,
        feelingsDocs,
        consultationsDocs,
        rendezvousDocs,
      );

      setState(() {});
    } catch (e) {
      _markdownContent = '# Erreur\n\nImpossible de charger les données supplémentaires.\n\n**Erreur:** $e\n\n*Veuillez vérifier votre connexion internet et réessayer.*';
      setState(() {});
    }
  }

  void _initializeControllers(Map<String, dynamic> data) {
    // Liste des champs qui seront éditables
    final editableFields = [
      'weight', 'height', 'email', 'telephone', 'country', 'province', 
      'city', 'district', 'avenue', 'house_number', 'antecedentsMedicaux'
    ];

    data.forEach((key, value) {
      if (!nonOtherInfoEditableKeys.contains(key)) {
        editableFields.add(key);
      }
    });

    // Initialiser ou mettre à jour les contrôleurs
    for (var key in editableFields) {
      var textValue = '';
      if (key == 'telephone') {
        textValue = data['telephone']?.toString() ?? data['phone']?.toString() ?? '';
      } else {
        textValue = data[key]?.toString() ?? '';
      }
      if (_controllers.containsKey(key)) {
        _controllers[key]!.text = textValue;
      } else {
        _controllers[key] = TextEditingController(text: textValue);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> updatedData = {};
      _controllers.forEach((key, controller) {
        var value = controller.text;
        // Pour les champs numériques, on essaie de les convertir.
        if (key == 'weight' || key == 'height') {
          updatedData[key] = num.tryParse(value.replaceAll(',', '.')); // Gère la virgule et le point
        } else if (key == 'telephone') {
          updatedData['phone'] = value.trim().isNotEmpty ? value.trim() : null; // Sauvegarder sous la clé 'phone'
        } else {
          // Pour les autres champs, on enregistre la chaîne, ou null si vide.
          updatedData[key] = value.trim().isNotEmpty ? value.trim() : null;
        }
      });

      try {
        await FirebaseFirestore.instance.collection('users').doc(widget.patientId).update(updatedData);
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Modifications enregistrées avec succès.'),
            backgroundColor: theme.colorScheme.primary,
          ));
        }
      } catch (e) {
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Erreur lors de la sauvegarde : $e'),
            backgroundColor: theme.colorScheme.error,
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  String _generateMarkdownContent(
    Map<String, dynamic>? userData,
    List<QueryDocumentSnapshot> feelings,
    List<QueryDocumentSnapshot> consultations,
    List<QueryDocumentSnapshot> rendezvous,
  ) {
    StringBuffer markdown = StringBuffer();
    final bool isCurrentUserThePatient = _auth.currentUser?.uid == widget.patientId;

    // En-tête
    markdown.writeln('# 📋 Dossier Médical');
    markdown.writeln();
    if (isCurrentUserThePatient) {
      // Pour le patient : afficher toutes les informations
    markdown.writeln('**Patient:** ${widget.patientName}');
    markdown.writeln('**ID:** ${widget.patientId}');
    markdown.writeln('**Généré le:** ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}');
    } else {
      // Pour le médecin : afficher seulement l'ID
      markdown.writeln('**ID Patient:** ${widget.patientId}');
      markdown.writeln('**Consulté le:** ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}');
    }
    markdown.writeln();

    // Informations personnelles
    markdown.writeln('## 👤 Informations Personnelles');
    markdown.writeln();
    if (userData != null) {
      if (isCurrentUserThePatient) {
        // Pour le patient : afficher toutes les informations
      _addMarkdownField(markdown, 'Nom complet', _getFullName(userData));
      _addMarkdownField(markdown, 'Email', userData['email']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'Téléphone', userData['phone']?.toString() ?? userData['telephone']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'Date de naissance', userData['dob']?.toString() ?? userData['dateNaissance']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'Âge', _calculateAge(userData['dob']?.toString() ?? userData['dateNaissance']?.toString()));
      _addMarkdownField(markdown, 'Sexe', userData['gender']?.toString() ?? userData['sexe']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'Groupe sanguin', userData['bloodGroup']?.toString() ?? userData['groupeSanguin']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'Poids', userData['weight']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'Taille', userData['height']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'Antécédents médicaux', userData['antecedentsMedicaux']?.toString() ?? 'Aucun');
      _addMarkdownField(markdown, 'Allergies', userData['allergies']?.toString() ?? 'Aucune');
      _addMarkdownField(markdown, 'Handicap', userData['handicap']?.toString() ?? 'Aucun');
      } else {
        // Pour le médecin : afficher seulement les informations médicales pertinentes
        _addMarkdownField(markdown, 'Âge', _calculateAge(userData['dob']?.toString() ?? userData['dateNaissance']?.toString()));
        _addMarkdownField(markdown, 'Sexe', userData['gender']?.toString() ?? userData['sexe']?.toString() ?? 'Non renseigné');
        _addMarkdownField(markdown, 'Groupe sanguin', userData['bloodGroup']?.toString() ?? userData['groupeSanguin']?.toString() ?? 'Non renseigné');
        _addMarkdownField(markdown, 'Poids', userData['weight']?.toString() ?? 'Non renseigné');
        _addMarkdownField(markdown, 'Taille', userData['height']?.toString() ?? 'Non renseigné');
        _addMarkdownField(markdown, 'Antécédents médicaux', userData['antecedentsMedicaux']?.toString() ?? 'Aucun');
        _addMarkdownField(markdown, 'Allergies', userData['allergies']?.toString() ?? 'Aucune');
        _addMarkdownField(markdown, 'Handicap', userData['handicap']?.toString() ?? 'Aucun');
      }
    } else {
      markdown.writeln('*Aucune information personnelle disponible*');
    }
    markdown.writeln();

    // Adresse - seulement pour le patient
    if (isCurrentUserThePatient) {
    markdown.writeln('## 🏠 Adresse');
    markdown.writeln();
    if (userData != null) {
      _addMarkdownField(markdown, 'Pays', userData['country']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'Province', userData['province']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'Ville', userData['city']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'District/Quartier', userData['district']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'Avenue', userData['avenue']?.toString() ?? 'Non renseigné');
      _addMarkdownField(markdown, 'Numéro de maison', userData['house_number']?.toString() ?? 'Non renseigné');
    } else {
      markdown.writeln('*Aucune information d\'adresse disponible*');
    }
    markdown.writeln();
    }

    // Historique des symptômes (Feelings) - 5 dernières soumissions
    markdown.writeln('## 🩹 Historique des Symptômes (5 dernières soumissions)');
    markdown.writeln();
    if (feelings.isNotEmpty) {
      // Limiter aux 5 dernières soumissions
      final limitedFeelings = feelings.take(5).toList();
      for (int i = 0; i < limitedFeelings.length; i++) {
        var feeling = limitedFeelings[i].data() as Map<String, dynamic>;
        markdown.writeln('### 📝 Soumission ${i + 1}');
        markdown.writeln();
        
        // Date
        if (feeling['timestamp'] != null) {
          var timestamp = feeling['timestamp'] as Timestamp;
          markdown.writeln('**Date:** ${DateFormat('dd/MM/yyyy à HH:mm').format(timestamp.toDate())}');
        }
        
        // Symptômes
        if (feeling['selectedSymptoms'] != null) {
          var symptoms = feeling['selectedSymptoms'] as List<dynamic>;
          if (symptoms.isNotEmpty) {
            markdown.writeln('**Symptômes signalés:**');
            for (var symptom in symptoms) {
              markdown.writeln('- $symptom');
            }
          }
        }
        
        // Message
        if (feeling['message'] != null && feeling['message'].toString().isNotEmpty) {
          markdown.writeln('**Description:** ${feeling['message']}');
        }
        
        // Consultation pour
        if (feeling['consultationFor'] != null) {
          markdown.writeln('**Consultation pour:** ${feeling['consultationFor'] == 'self' ? 'Soi-même' : 'Autre personne'}');
        }
        
        // Images
        if (feeling['imageUrls'] != null) {
          var images = feeling['imageUrls'] as List<dynamic>;
          if (images.isNotEmpty) {
            markdown.writeln('**Images jointes:** ${images.length} image(s)');
          }
        }
        
        // Audio
        if (feeling['audioUrl'] != null) {
          markdown.writeln('**Message vocal:** Oui');
        }
        
        markdown.writeln();
      }
    } else {
      markdown.writeln('*Aucun symptôme enregistré*');
    }

    // Consultations à domicile - masquées pour tous
    // Cette section est commentée pour ne pas afficher les consultations à domicile
    /*
    markdown.writeln('## 🏥 Consultations à Domicile');
    markdown.writeln();
    if (consultations.isNotEmpty) {
      for (int i = 0; i < consultations.length; i++) {
        var consultation = consultations[i].data() as Map<String, dynamic>;
        markdown.writeln('### 🩺 Consultation ${i + 1}');
        markdown.writeln();
        
        // Date
        if (consultation['timestamp'] != null) {
          var timestamp = consultation['timestamp'] as Timestamp;
          markdown.writeln('**Date:** ${DateFormat('dd/MM/yyyy à HH:mm').format(timestamp.toDate())}');
        }
        
        // Statut
        markdown.writeln('**Statut:** ${consultation['status']?.toString() ?? 'Inconnu'}');
        
        // Ville
        markdown.writeln('**Ville:** ${consultation['city']?.toString() ?? 'Non renseigné'}');
        
        // Adresse
        markdown.writeln('**Adresse:** ${consultation['address']?.toString() ?? 'Non renseigné'}');
        
        // Symptômes
        if (consultation['symptoms'] != null) {
          var symptoms = consultation['symptoms'] as List<dynamic>;
          if (symptoms.isNotEmpty) {
            markdown.writeln('**Symptômes:**');
            for (var symptom in symptoms) {
              markdown.writeln('- $symptom');
            }
          }
        }
        
        // Message
        if (consultation['message'] != null && consultation['message'].toString().isNotEmpty) {
          markdown.writeln('**Description:** ${consultation['message']}');
        }
        
        // Médecin assigné
        if (consultation['assignedDoctorId'] != null) {
          markdown.writeln('**Médecin assigné:** ${consultation['assignedDoctorId']}');
        }
        
        markdown.writeln();
      }
    } else {
      markdown.writeln('*Aucune consultation à domicile enregistrée*');
    }
    */

    // Rendez-vous - masqués pour tous
    // Cette section est commentée pour ne pas afficher les rendez-vous
    /*
    markdown.writeln('## 📅 Rendez-vous');
    markdown.writeln();
    if (rendezvous.isNotEmpty) {
      for (int i = 0; i < rendezvous.length; i++) {
        var rdv = rendezvous[i].data() as Map<String, dynamic>;
        markdown.writeln('### 📋 Rendez-vous ${i + 1}');
        markdown.writeln();
        
        // Date
        if (rdv['timestamp'] != null) {
          var timestamp = rdv['timestamp'] as Timestamp;
          markdown.writeln('**Date de demande:** ${DateFormat('dd/MM/yyyy à HH:mm').format(timestamp.toDate())}');
        }
        
        // Statut
        markdown.writeln('**Statut:** ${rdv['status']?.toString() ?? 'Inconnu'}');
        
        // Spécialité
        markdown.writeln('**Spécialité:** ${rdv['specialty']?.toString() ?? 'Non renseigné'}');
        
        // Message
        if (rdv['message'] != null && rdv['message'].toString().isNotEmpty) {
          markdown.writeln('**Message:** ${rdv['message']}');
        }
        
        markdown.writeln();
      }
    } else {
      markdown.writeln('*Aucun rendez-vous enregistré*');
    }
    */

    // Pied de page
    markdown.writeln('---');
    markdown.writeln();
    markdown.writeln('*Ce dossier médical a été généré automatiquement par Hospital Virtuel (Afya Bora)*');
    markdown.writeln('*Pour toute question, contactez votre médecin ou le support technique*');

    return markdown.toString();
  }

  void _addMarkdownField(StringBuffer markdown, String label, String value) {
    markdown.writeln('**$label:** $value');
  }

  String _getFullName(Map<String, dynamic> userData) {
    String prenom = userData['prenom']?.toString() ?? userData['first_name']?.toString() ?? '';
    String nom = userData['nom']?.toString() ?? userData['last_name']?.toString() ?? '';
    String postnom = userData['postnom']?.toString() ?? '';
    
    List<String> nameParts = [prenom, nom, postnom].where((s) => s.isNotEmpty).toList();
    return nameParts.isNotEmpty ? nameParts.join(' ') : 'Non renseigné';
  }

  String _calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty) {
      return 'Non renseigné';
    }
    try {
      final DateFormat format = DateFormat('d/M/yyyy');
      final DateTime birthDate = format.parse(dobString);
      final DateTime today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return '$age ans';
    } catch (e) {
      return 'Non renseigné';
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _markdownContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dossier médical copié dans le presse-papiers'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareDossier() {
    // Ici vous pouvez ajouter la fonctionnalité de partage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonctionnalité de partage à implémenter'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 768;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isCurrentUserThePatient = _auth.currentUser?.uid == widget.patientId;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          isCurrentUserThePatient 
            ? 'Mon Dossier Médical'
            : 'Dossier de ${widget.patientName}',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isDesktop ? 24 : 20,
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
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white),
              onPressed: _copyToClipboard,
              tooltip: 'Copier le dossier',
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareDossier,
              tooltip: 'Partager le dossier',
            ),
          ],
          if (isCurrentUserThePatient)
            IconButton(
              icon: Icon(_isEditing ? Icons.save_alt_outlined : Icons.edit_outlined, color: Colors.white),
              tooltip: _isEditing ? 'Enregistrer' : 'Modifier',
              onPressed: () async {
                if (_isEditing) {
                  await _saveChanges();
                }
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
            ),
        ],
      ),
      backgroundColor: isDarkMode ? Colors.black : theme.colorScheme.surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patientId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.blue.shade400 : Colors.blue.shade600,
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur: ${snapshot.error}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Aucune donnée de dossier trouvée pour ce patient.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            );
          }

          _userData = snapshot.data!.data() as Map<String, dynamic>;
          if (!_isEditing) {
            _initializeControllers(_userData!);
            // Charger les données supplémentaires une seule fois
            if (_markdownContent.isEmpty) {
              _loadAdditionalData();
            }
          }

          return _isEditing
              ? _buildEditForm(isDarkMode)
              : isDesktop
                  ? _buildDesktopLayout(isDarkMode)
                  : _buildMobileLayout(isDarkMode);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [Colors.black, Colors.grey.shade900]
              : [Colors.grey.shade50, Colors.white],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Card(
              elevation: 12,
              shadowColor: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.2),
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(40.0),
                child: _buildMarkdownContent(isDarkMode),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [Colors.black, Colors.grey.shade900]
              : [Colors.grey.shade50, Colors.white],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _buildMarkdownContent(isDarkMode),
      ),
    );
  }

  Widget _buildMarkdownContent(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
        ),
      ),
      child: _buildFormattedMarkdown(isDarkMode),
    );
  }

  Widget _buildFormattedMarkdown(bool isDarkMode) {
    final lines = _markdownContent.split('\n');
    final List<Widget> widgets = [];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (line.startsWith('# ')) {
        // Titre principal (H1)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
      child: SelectableText(
              line.substring(2),
              style: GoogleFonts.robotoMono(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        // Titre secondaire (H2)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
            child: SelectableText(
              line.substring(3),
              style: GoogleFonts.robotoMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        // Titre tertiaire (H3)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
            child: SelectableText(
              line.substring(4),
              style: GoogleFonts.robotoMono(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: isDarkMode ? Colors.green.shade300 : Colors.green.shade700,
              ),
            ),
          ),
        );
      } else if (line.contains('**') && line.contains(':')) {
        // Texte avec label en gras (ex: **Poids:** 72)
        final parts = line.split('**');
        if (parts.length >= 3) {
          final label = parts[1]; // Le texte entre **
          final value = parts[2].trim(); // Le reste après **
          
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    '$label ',
        style: GoogleFonts.robotoMono(
          fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.6,
                      color: isDarkMode ? Colors.grey.shade200 : Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      value,
                      style: GoogleFonts.robotoMono(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
          height: 1.6,
          color: isDarkMode ? Colors.grey.shade300 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Fallback pour les autres cas de **
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: SelectableText(
                line.replaceAll('**', ''),
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.6,
                  color: isDarkMode ? Colors.grey.shade200 : Colors.black87,
                ),
              ),
            ),
          );
        }
      } else if (line.startsWith('*') && line.endsWith('*') && !line.startsWith('**')) {
        // Texte en italique
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: SelectableText(
              line.substring(1, line.length - 1),
              style: GoogleFonts.robotoMono(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.6,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
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
                  style: GoogleFonts.robotoMono(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey.shade300 : Colors.black87,
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    line.substring(2),
                    style: GoogleFonts.robotoMono(
                      fontSize: 14,
                      height: 1.6,
                      color: isDarkMode ? Colors.grey.shade300 : Colors.black87,
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
            child: SelectableText(
              line,
              style: GoogleFonts.robotoMono(
                fontSize: 14,
                height: 1.6,
                color: isDarkMode ? Colors.grey.shade300 : Colors.black87,
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

  Widget _buildEditForm(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [Colors.black, Colors.grey.shade900]
              : [Colors.grey.shade50, Colors.white],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Card(
                elevation: 4,
                color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            color: isDarkMode ? Colors.blue.shade400 : Colors.blue.shade600,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Modifier les informations',
                            style: GoogleFonts.lato(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Modifiez les informations que vous souhaitez mettre à jour',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Informations personnelles
              _buildSectionCard(
                'Informations Personnelles',
                Icons.person_outline,
                [
                  _buildTextField('Poids (kg)', 'weight', TextInputType.number),
                  _buildTextField('Taille (cm)', 'height', TextInputType.number),
                  _buildTextField('Email', 'email', TextInputType.emailAddress),
                  _buildTextField('Téléphone', 'telephone', TextInputType.phone),
                ],
                isDarkMode,
              ),

              const SizedBox(height: 16),

              // Adresse
              _buildSectionCard(
                'Adresse',
                Icons.location_on_outlined,
                [
                  _buildTextField('Pays', 'country', TextInputType.text),
                  _buildTextField('Province', 'province', TextInputType.text),
                  _buildTextField('Ville', 'city', TextInputType.text),
                  _buildTextField('District/Quartier', 'district', TextInputType.text),
                  _buildTextField('Avenue', 'avenue', TextInputType.text),
                  _buildTextField('Numéro de maison', 'house_number', TextInputType.text),
                ],
                isDarkMode,
              ),

              const SizedBox(height: 16),

              // Antécédents médicaux
              _buildSectionCard(
                'Antécédents Médicaux',
                Icons.medical_information_outlined,
                [
                  _buildTextField('Antécédents médicaux', 'antecedentsMedicaux', TextInputType.multiline, maxLines: 3),
                ],
                isDarkMode,
              ),

              const SizedBox(height: 20),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                        });
                      },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Annuler'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveChanges,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children, bool isDarkMode) {
    return Card(
      elevation: 2,
      color: isDarkMode ? Colors.grey.shade800 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isDarkMode ? Colors.blue.shade400 : Colors.blue.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String key, TextInputType inputType, {int maxLines = 1}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: inputType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade50,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
          ),
        ),
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        validator: (value) {
          if (key == 'email' && value != null && value.isNotEmpty) {
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Veuillez entrer un email valide';
            }
          }
          if (key == 'weight' || key == 'height') {
            if (value != null && value.isNotEmpty && num.tryParse(value.replaceAll(',', '.')) == null) {
              return 'Veuillez entrer un nombre valide';
            }
          }
          return null;
        },
      ),
    );
  }
}

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
