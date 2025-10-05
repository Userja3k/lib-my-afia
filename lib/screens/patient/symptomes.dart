import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb
import 'package:path_provider/path_provider.dart';


import 'package:flutter_sound/flutter_sound.dart';

// import 'full_screen_image_page.dart'; // Supprimé car la confirmation d'image unique est retirée
import 'package:google_fonts/google_fonts.dart'; // Pour des polices plus attrayantes
import 'package:hospital_virtuel/screens/settings/settings.dart';

enum ConsultationTarget { self, other }

const String consultationTargetSelf = 'Pour moi-même';
const String consultationTargetOther = 'Pour une autre personne';

class SymptomesPage extends StatefulWidget {
  final String doctorId;
  final String? specialty;
  final bool isDesktop;

  const SymptomesPage({
    super.key, 
    required this.doctorId,
    this.specialty,
    this.isDesktop = false,
  });

  @override
  State<SymptomesPage> createState() => _SymptomesPageState();
}

class _SymptomesPageState extends State<SymptomesPage> {
  final List<String> _ageRanges = const ['0-1 an', '2-5 ans', '6-12 ans', '13-17 ans', '18-30 ans', '31-50 ans', '51+ ans'];
  final List<String> _sexes = const ['Masculin', 'Féminin'];
  final List<String> _bloodGroups = const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Inconnu'];
  final List<String> _disabilities = const ['Aucun', 'Moteur', 'Visuel', 'Auditif', 'Mental', 'Autre'];

  String? _otherPatientAgeRange;
  String? _otherPatientSex;
  String? _otherPatientBloodGroup;
  String? _otherPatientDisability;

  ConsultationTarget _consultationTarget = ConsultationTarget.self;
  final List<Symptom> _symptoms = [
    Symptom(name: 'Fièvre', isChecked: false),
    Symptom(name: 'Toux', isChecked: false),
    Symptom(name: 'Maux de tête', isChecked: false),
    Symptom(name: 'Nausées', isChecked: false),
    Symptom(name: 'Fatigue', isChecked: false),
    Symptom(name: 'Douleurs musculaires', isChecked: false),
    Symptom(name: 'Difficultés respiratoires', isChecked: false),
    Symptom(name: 'Maux de gorge', isChecked: false),
    Symptom(name: 'Perte de goût/odorat', isChecked: false),
    Symptom(name: 'Vertiges', isChecked: false),
  ];

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _otherPatientDetailsController = TextEditingController();
  final TextEditingController _otherPatientHeightController = TextEditingController();
  final TextEditingController _otherPatientWeightController = TextEditingController();
  final TextEditingController _otherPatientDisabilityDetailsController = TextEditingController();

  final List<XFile> _imageFiles = []; // Modifié pour supporter plusieurs images
  String? _audioPath;
  bool _isRecording = false;
 
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  Future<void> _submitSymptoms() async {
    setState(() => _isSubmitting = true);
    List<String> selectedSymptoms = _symptoms
        .where((symptom) => symptom.isChecked)
        .map((symptom) => symptom.name)
        .toList();
    String message = _messageController.text.trim();

    if (selectedSymptoms.isEmpty && message.isEmpty && _imageFiles.isEmpty && _audioPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Veuillez sélectionner au moins un symptôme ou ajouter un message.'),
          backgroundColor: Colors.orangeAccent,
        ));
      }
      setState(() => _isSubmitting = false);
      return;
    }

    if (_consultationTarget == ConsultationTarget.other) {
      if (_otherPatientAgeRange == null || _otherPatientSex == null) {
        // Cette vérification est conservée, mais les suivantes sont plus spécifiques.
      }

      // Validation plus détaillée pour les champs de "l'autre personne"
      String? validationErrorMsg;
      if (_otherPatientAgeRange == null) {
        validationErrorMsg = 'Veuillez préciser la tranche d\'âge pour l\'autre personne.';
        
      } else if (_otherPatientSex == null) {
        validationErrorMsg = 'Veuillez préciser le sexe pour l\'autre personne.';
      } else if (_otherPatientBloodGroup == null) {
        validationErrorMsg = 'Veuillez préciser le groupe sanguin pour l\'autre personne.';
      } else if (_otherPatientDisability == null) {
        validationErrorMsg = 'Veuillez préciser le type d\'handicap pour l\'autre personne.';
      } else if (_otherPatientDisability == 'Autre' && _otherPatientDisabilityDetailsController.text.trim().isEmpty) {
        validationErrorMsg = 'Veuillez préciser les détails de l\'handicap "Autre".';
      }

      if (validationErrorMsg != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(validationErrorMsg),
            backgroundColor: Colors.orangeAccent,
          ));
        }
        setState(() => _isSubmitting = false);
        return;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Utilisateur non authentifié. Veuillez vous reconnecter.'),
        backgroundColor: Colors.redAccent,
      ));
      }
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      DateTime? lastSubmitted = userDoc.exists && (userDoc.data() as Map).containsKey('lastSubmitted')
          ? (userDoc.data() as Map)['lastSubmitted']?.toDate()
          : null;
      DateTime now = DateTime.now();

      if (lastSubmitted != null && now.difference(lastSubmitted).inMinutes < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vous avez déjà envoyé vos symptômes. Veuillez réessayer plus tard.'),
          backgroundColor: Colors.blueAccent,
        ));
        }
        setState(() => _isSubmitting = false);
        return;
      }

      List<String> imageUrls = [];
      if (_imageFiles.isNotEmpty) {
        for (XFile imageFile in _imageFiles) {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}-${imageFile.name}';
          final ref = FirebaseStorage.instance.ref().child('symptoms_images/${widget.doctorId}/${user.uid}/$fileName');
          if (kIsWeb) {
            await ref.putData(await imageFile.readAsBytes(), SettableMetadata(contentType: imageFile.mimeType ?? 'image/jpeg'));
          } else {
            await ref.putFile(File(imageFile.path));
          }
          imageUrls.add(await ref.getDownloadURL());
        }
      } else {
        // Si aucune image n'est sélectionnée, demandez confirmation pour envoyer sans images.
        final confirmDirectSubmit = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Confirmer l\'envoi'),
              content: const Text('Aucune image n\'a été jointe. Voulez-vous continuer ?'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white),
                  child: const Text('Oui, continuer'),
                ),
              ],
            );
          },
        );

        if (confirmDirectSubmit != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Envoi des symptômes annulé."),
            backgroundColor: Colors.grey,
          ));
          }
          setState(() => _isSubmitting = false);
          return;
        }
      }

      String? audioUrl;
      if (_audioPath != null) {
        final fileName = 'symptom_audio_${DateTime.now().millisecondsSinceEpoch}.${kIsWeb ? 'webm' : 'aac'}';
        final ref = FirebaseStorage.instance.ref().child('symptoms_audio/${widget.doctorId}/${user.uid}/$fileName');
        if (kIsWeb) {
          // Sur le web, _audioPath est une URL blob. On crée un XFile pour lire les bytes.
          final audioFile = XFile(_audioPath!);
          await ref.putData(await audioFile.readAsBytes(), SettableMetadata(contentType: 'audio/webm'));
        } else {
          // Sur mobile, _audioPath est un chemin de fichier local.
          final audioFile = File(_audioPath!);
          await ref.putFile(audioFile, SettableMetadata(contentType: 'audio/aac'));
        }
        audioUrl = await ref.getDownloadURL();
      }

      Map<String, dynamic> symptomsData = {
        'selectedSymptoms': selectedSymptoms,
        'message': message,
        'imageUrls': imageUrls, // Modifié pour une liste d'URLs
        'audioUrl': audioUrl,
        'consultationFor': _consultationTarget == ConsultationTarget.self ? 'self' : 'other',
        'doctorId': widget.doctorId,
        'specialty': widget.specialty, // Ajout de la spécialité
        'patientId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (_consultationTarget == ConsultationTarget.other) {
        symptomsData.addAll({
          'otherPatientAgeRange': _otherPatientAgeRange,
          'otherPatientSex': _otherPatientSex,
          'otherPatientDetails': _otherPatientDetailsController.text.trim(),
          'otherPatientHeight': _otherPatientHeightController.text.trim(),
          'otherPatientWeight': _otherPatientWeightController.text.trim(),
          'otherPatientBloodGroup': _otherPatientBloodGroup,
          'otherPatientDisability': _otherPatientDisability,
          if (_otherPatientDisability == 'Autre')
            'otherPatientDisabilityDetails': _otherPatientDisabilityDetailsController.text.trim(),
        });
      }

      // Enregistrement dans la collection 'feelings'
      await FirebaseFirestore.instance.collection('feelings').add(symptomsData);

      // Mettre à jour 'lastSubmitted' dans la collection 'users'
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'lastSubmitted': now,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vos informations ont été envoyées avec succès.'),
          backgroundColor: Colors.green,
        ));
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur lors de l\'envoi des informations: $e'),
        backgroundColor: Colors.redAccent,
      ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickImage() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 70) ?? [];
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _imageFiles.addAll(pickedFiles);
      });
    }
  }

  
  Future<void> _toggleRecording() async {
    // On demande la permission uniquement sur mobile, comme dans le chat
    if (!kIsWeb && !await Permission.microphone.request().isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission microphone refusée'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_recorder.isRecording) {
      // Arrêter l'enregistrement
      try {
        final path = await _recorder.stopRecorder();
        setState(() {
          _isRecording = false;
          _audioPath = path;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'arrêt de l\'enregistrement: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Démarrer l'enregistrement
      try {
        String filePath;
        Codec codec;
        if (kIsWeb) {
          // Pour le web, flutter_sound utilise le codec opusWebM et le nom du fichier est un placeholder.
          filePath = 'web_symptom_audio.webm';
          codec = Codec.opusWebM;
        } else {
          // Pour mobile
          final tempDir = await getTemporaryDirectory();
          filePath = '${tempDir.path}/symptom_audio_${DateTime.now().millisecondsSinceEpoch}.aac';
          codec = Codec.aacADTS;
        }

        await _recorder.startRecorder(toFile: filePath, codec: codec);
        setState(() {
          _isRecording = true;
          _audioPath = null; // On efface l'ancien enregistrement pour en créer un nouveau
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'enregistrement: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _playAudio() async {
    if (_audioPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun message vocal à écouter'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      if (_player.isPlaying) {
        // Si en cours de lecture, mettre en pause
        await _player.pausePlayer();
        if (mounted) {
          setState(() {});
        }
      } else if (_player.isPaused) {
        // Si en pause, reprendre la lecture
        await _player.resumePlayer();
        if (mounted) {
          setState(() {});
        }
      } else {
        // Démarrer la lecture
        await _player.startPlayer(
          fromURI: _audioPath,
          whenFinished: () {
            if (mounted) {
              setState(() {});
            }
          },
        );
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la lecture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteAudio() {
    if (_audioPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun message vocal à supprimer'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Arrêter la lecture si elle est en cours
    if (_player.isPlaying || _player.isPaused) {
      _player.stopPlayer();
    }
    
    setState(() => _audioPath = null);
  }

  void _resetOtherPatientFields() {
    setState(() {
      _otherPatientAgeRange = null;
      _otherPatientSex = null;
      _otherPatientDetailsController.clear();
      _otherPatientHeightController.clear();
      _otherPatientWeightController.clear();
      _otherPatientBloodGroup = null;
      _otherPatientDisability = null;
      _otherPatientDisabilityDetailsController.clear();
      _imageFiles.clear(); // Optionnel: effacer aussi les images si besoin
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      await _recorder.openRecorder();
      await _player.openPlayer();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'initialisation audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Décrire vos symptômes',
            style: GoogleFonts.lato(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: widget.isDesktop ? 24 : 20,
            )),
        centerTitle: widget.isDesktop,
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
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(leading: Icon(Icons.settings), title: Text('Paramètres')),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Plus d\'options',
          )
        ],
      ),
      body: widget.isDesktop ? _buildDesktopLayout(theme, isDarkMode) : _buildMobileLayout(theme, isDarkMode),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode 
            ? [Colors.grey.shade900, Colors.grey.shade800]
            : [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 48.0),
            elevation: 8.0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              children: [
                // En-tête avec gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade800, Colors.lightBlue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.healing_outlined,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Décrire vos symptômes',
                              style: GoogleFonts.lato(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sélectionnez vos symptômes et ajoutez des détails',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Contenu principal
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 100.0), // Ajout de padding en bas
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionCard(
                          title: 'Pour qui est cette consultation ?',
                          icon: Icons.people_alt_outlined,
                          theme: theme,
                          isDarkMode: isDarkMode,
                          child: Column(
                            children: [
                              RadioListTile<ConsultationTarget>(
                                title: Text(consultationTargetSelf, style: GoogleFonts.roboto(fontSize: 15, color: isDarkMode ? Colors.white : theme.textTheme.bodyMedium?.color)),
                                value: ConsultationTarget.self,
                                groupValue: _consultationTarget,
                                onChanged: (ConsultationTarget? value) {
                                  if (value != null) {
                                    setState(() {
                                      _consultationTarget = value;
                                      if (value == ConsultationTarget.self) {
                                        _resetOtherPatientFields();
                                      }
                                    });
                                  }
                                },
                                activeColor: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                                contentPadding: EdgeInsets.zero,
                              ),
                              RadioListTile<ConsultationTarget>(
                                title: Text(consultationTargetOther, style: GoogleFonts.roboto(fontSize: 15, color: isDarkMode ? Colors.white : theme.textTheme.bodyMedium?.color)),
                                value: ConsultationTarget.other,
                                groupValue: _consultationTarget,
                                onChanged: (ConsultationTarget? value) {
                                  if (value != null) {
                                    setState(() {
                                      _consultationTarget = value;
                                    });
                                  }
                                },
                                activeColor: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                        if (_consultationTarget == ConsultationTarget.other)
                          _buildSectionCard(
                            title: 'Informations sur l\'autre personne',
                            icon: Icons.person_search_outlined,
                            theme: theme,
                            isDarkMode: isDarkMode,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),
                                _buildDropdownField(_ageRanges, 'Tranche d\'âge', _otherPatientAgeRange, (val) => setState(() => _otherPatientAgeRange = val), theme: theme, isDarkMode: isDarkMode),
                                const SizedBox(height: 16),
                                _buildDropdownField(_sexes, 'Sexe', _otherPatientSex, (val) => setState(() => _otherPatientSex = val), theme: theme, isDarkMode: isDarkMode),
                                const SizedBox(height: 16),
                                _buildTextField(_otherPatientHeightController, 'Taille (cm) (optionnel)', TextInputType.number, theme: theme, isDarkMode: isDarkMode),
                                const SizedBox(height: 16),
                                _buildTextField(_otherPatientWeightController, 'Poids (kg) (optionnel)', TextInputType.number, theme: theme, isDarkMode: isDarkMode),
                                const SizedBox(height: 16),
                                _buildDropdownField(_bloodGroups, 'Groupe Sanguin', _otherPatientBloodGroup, (val) => setState(() => _otherPatientBloodGroup = val), theme: theme, isDarkMode: isDarkMode),
                                const SizedBox(height: 16),
                                _buildDropdownField(_disabilities, 'Handicap', _otherPatientDisability, (val) => setState(() => _otherPatientDisability = val), theme: theme, isDarkMode: isDarkMode),
                                if (_otherPatientDisability == 'Autre') ...[
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    _otherPatientDisabilityDetailsController,
                                    'Préciser l\'handicap *',
                                    TextInputType.text,
                                    maxLines: 2,
                                    theme: theme,
                                    isDarkMode: isDarkMode,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Veuillez préciser l\'handicap.';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                const SizedBox(height: 16),
                                _buildTextField(_otherPatientDetailsController, 'Précisions supplémentaires (optionnel)', TextInputType.text, maxLines: 3, theme: theme, isDarkMode: isDarkMode),
                              ],
                            ),
                          ),
                        _buildSectionCard(
                          title: 'Cochez vos symptômes',
                          icon: Icons.checklist_rtl_outlined,
                          theme: theme,
                          isDarkMode: isDarkMode,
                          child: Column(
                            children: _symptoms.map((symptom) {
                              return CheckboxListTile(
                                title: Text(symptom.name, style: GoogleFonts.roboto(fontSize: 15, color: isDarkMode ? Colors.white : theme.textTheme.bodyMedium?.color)),
                                value: symptom.isChecked,
                                onChanged: (bool? value) {
                                  setState(() {
                                    symptom.isChecked = value ?? false;
                                  });
                                },
                                activeColor: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                                controlAffinity: ListTileControlAffinity.leading,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ),
                        if (_imageFiles.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Images jointes:", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : theme.textTheme.titleMedium?.color)),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _imageFiles.length,
                                    itemBuilder: (context, index) {
                                      final imageFile = _imageFiles[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 10.0),
                                        child: Stack(
                                          alignment: Alignment.topRight,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: kIsWeb
                                                  ? Image.network(imageFile.path, height: 100, width: 100, fit: BoxFit.cover)
                                                  : Image.file(File(imageFile.path), height: 100, width: 100, fit: BoxFit.cover),
                                            ),
                                            Container(
                                              margin: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
                                              child: InkWell(
                                                onTap: () => setState(() => _imageFiles.removeAt(index)),
                                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_audioPath != null)
                          _buildAudioPlayerWidget(theme, isDarkMode),
                      ],
                    ),
                  ),
                ),
                
                // Barre de saisie
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: _buildBottomBar(theme, isDarkMode),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(ThemeData theme, bool isDarkMode) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0), // Ajout de padding en bas
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  title: 'Pour qui est cette consultation ?',
                  icon: Icons.people_alt_outlined,
                  theme: theme,
                  isDarkMode: isDarkMode,
                  child: Column(
                    children: [
                      RadioListTile<ConsultationTarget>(
                        title: Text(consultationTargetSelf, style: GoogleFonts.roboto(fontSize: 15, color: isDarkMode ? Colors.white : theme.textTheme.bodyMedium?.color)),
                        value: ConsultationTarget.self,
                        groupValue: _consultationTarget,
                        onChanged: (ConsultationTarget? value) {
                          if (value != null) {
                            setState(() {
                              _consultationTarget = value;
                              if (value == ConsultationTarget.self) {
                                _resetOtherPatientFields();
                              }
                            });
                          }
                        },
                        activeColor: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<ConsultationTarget>(
                        title: Text(consultationTargetOther, style: GoogleFonts.roboto(fontSize: 15, color: isDarkMode ? Colors.white : theme.textTheme.bodyMedium?.color)),
                        value: ConsultationTarget.other,
                        groupValue: _consultationTarget,
                        onChanged: (ConsultationTarget? value) {
                          if (value != null) {
                            setState(() {
                              _consultationTarget = value;
                            });
                          }
                        },
                        activeColor: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                if (_consultationTarget == ConsultationTarget.other)
                  _buildSectionCard(
                    title: 'Informations sur l\'autre personne',
                    icon: Icons.person_search_outlined,
                    theme: theme,
                    isDarkMode: isDarkMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _buildDropdownField(_ageRanges, 'Tranche d\'âge', _otherPatientAgeRange, (val) => setState(() => _otherPatientAgeRange = val), theme: theme, isDarkMode: isDarkMode),
                        const SizedBox(height: 16),
                        _buildDropdownField(_sexes, 'Sexe', _otherPatientSex, (val) => setState(() => _otherPatientSex = val), theme: theme, isDarkMode: isDarkMode),
                        const SizedBox(height: 16),
                        _buildTextField(_otherPatientHeightController, 'Taille (cm) (optionnel)', TextInputType.number, theme: theme, isDarkMode: isDarkMode),
                        const SizedBox(height: 16),
                        _buildTextField(_otherPatientWeightController, 'Poids (kg) (optionnel)', TextInputType.number, theme: theme, isDarkMode: isDarkMode),
                        const SizedBox(height: 16),
                        _buildDropdownField(_bloodGroups, 'Groupe Sanguin', _otherPatientBloodGroup, (val) => setState(() => _otherPatientBloodGroup = val), theme: theme, isDarkMode: isDarkMode),
                        const SizedBox(height: 16),
                        _buildDropdownField(_disabilities, 'Handicap', _otherPatientDisability, (val) => setState(() => _otherPatientDisability = val), theme: theme, isDarkMode: isDarkMode),
                        if (_otherPatientDisability == 'Autre') ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            _otherPatientDisabilityDetailsController,
                            'Préciser l\'handicap *',
                            TextInputType.text,
                            maxLines: 2,
                            theme: theme,
                            isDarkMode: isDarkMode,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Veuillez préciser l\'handicap.';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildTextField(_otherPatientDetailsController, 'Précisions supplémentaires (optionnel)', TextInputType.text, maxLines: 3, theme: theme, isDarkMode: isDarkMode),
                      ],
                    ),
                  ),
                _buildSectionCard(
                  title: 'Cochez vos symptômes',
                  icon: Icons.checklist_rtl_outlined,
                  theme: theme,
                  isDarkMode: isDarkMode,
                  child: Column(
                    children: _symptoms.map((symptom) {
                      return CheckboxListTile(
                        title: Text(symptom.name, style: GoogleFonts.roboto(fontSize: 15, color: isDarkMode ? Colors.white : theme.textTheme.bodyMedium?.color)),
                        value: symptom.isChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            symptom.isChecked = value ?? false;
                          });
                        },
                        activeColor: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ),
                if (_imageFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Images jointes:", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : theme.textTheme.titleMedium?.color)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imageFiles.length,
                            itemBuilder: (context, index) {
                              final imageFile = _imageFiles[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 10.0),
                                child: Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: kIsWeb
                                          ? Image.network(imageFile.path, height: 100, width: 100, fit: BoxFit.cover)
                                          : Image.file(File(imageFile.path), height: 100, width: 100, fit: BoxFit.cover),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
                                      child: InkWell(
                                        onTap: () => setState(() => _imageFiles.removeAt(index)),
                                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_audioPath != null)
                  _buildAudioPlayerWidget(theme, isDarkMode),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: _buildBottomBar(theme, isDarkMode),
        ),
      ],
    );
  }



  Widget _buildAudioPlayerWidget(ThemeData theme, bool isDarkMode) {
    return Card(
      elevation: 2.0,
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Message vocal", 
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.w600, 
                    color: isDarkMode ? Colors.white : theme.textTheme.titleMedium?.color
                  )
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _player.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                        color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700, 
                        size: 28
                      ),
                      onPressed: _audioPath != null ? _playAudio : null,
                      tooltip: _player.isPlaying ? 'Pause' : 'Écouter',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_forever_outlined, 
                        color: Colors.red.shade600, 
                        size: 28
                      ),
                      onPressed: _deleteAudio,
                      tooltip: 'Supprimer',
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 8),
            // Barre de progression audio
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: _player.isPlaying ? 1 : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Indicateur de statut
            Row(
              children: [
                Icon(
                  _player.isPlaying ? Icons.volume_up : Icons.volume_down,
                  size: 16,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  _player.isPlaying ? 'En cours d\'écoute...' : (_player.isPaused ? 'Lecture en pause' : 'Message vocal enregistré'),
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, bool isDarkMode) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.photo_camera_back_outlined, 
            color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700, 
            size: 24
          ),
          onPressed: _pickImage,
          tooltip: 'Joindre une image',
        ),
        IconButton(
          icon: Icon(
            _isRecording ? Icons.stop_circle_outlined : Icons.mic_none_outlined, 
            color: _isRecording ? Colors.red.shade600 : (isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700), 
            size: 24
          ),
          onPressed: !_isSubmitting ? _toggleRecording : null,
          tooltip: _isRecording ? 'Arrêter l\'enregistrement' : 'Enregistrer un message vocal',
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade700 : Colors.white,
              borderRadius: BorderRadius.circular(25.0),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Autre chose à signaler ?',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
                style: GoogleFonts.roboto(
                  fontSize: 14, 
                  color: isDarkMode ? Colors.white : theme.textTheme.bodyMedium?.color
                ),
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _isSubmitting
            ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 20, 
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, 
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700
                    )
                  ),
                ),
              )
            : Material(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(25),
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: _submitSymptoms,
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Icon(Icons.send_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: isDesktop ? 28 : 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: isDesktop ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }











  Widget _buildSectionCard({required String title, required IconData icon, required Widget child, required ThemeData theme, required bool isDarkMode}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon, 
                  color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700, 
                  size: 20
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.lato(
                    fontSize: 16, 
                    fontWeight: FontWeight.w600, 
                    color: isDarkMode ? Colors.white : theme.textTheme.titleMedium?.color
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(List<String> items, String label, String? currentValue, ValueChanged<String?> onChanged, {bool isOptional = false, required ThemeData theme, required bool isDarkMode}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label + (isOptional ? '' : ' *'),
          labelStyle: TextStyle(color: isDarkMode ? Colors.grey.shade300 : theme.textTheme.bodyMedium?.color),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        value: currentValue,
        items: items.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value, style: GoogleFonts.roboto(color: isDarkMode ? Colors.white : theme.textTheme.bodyMedium?.color)));
        }).toList(),
        onChanged: onChanged,
        validator: isOptional ? null : (value) => value == null ? 'Champ requis' : null,
        style: GoogleFonts.roboto(color: isDarkMode ? Colors.white : theme.textTheme.bodyMedium?.color, fontSize: 15),
        icon: Icon(Icons.arrow_drop_down_circle_outlined, color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade600),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, TextInputType inputType, {int maxLines = 1, String? Function(String?)? validator, required ThemeData theme, required bool isDarkMode}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDarkMode ? Colors.grey.shade300 : theme.textTheme.bodyMedium?.color),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignLabelWithHint: maxLines > 1,
        ),
        keyboardType: inputType,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: GoogleFonts.roboto(fontSize: 15, color: isDarkMode ? Colors.white : theme.textTheme.bodyMedium?.color),
        validator: validator,
      ),
    );
  }



  @override
  void dispose() {
    _messageController.dispose();
    _otherPatientDetailsController.dispose();
    _otherPatientHeightController.dispose();
    _otherPatientWeightController.dispose();
    _otherPatientDisabilityDetailsController.dispose();
   _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }
}

class Symptom {
  String name;
  bool isChecked;

  Symptom({required this.name, this.isChecked = false});
}
