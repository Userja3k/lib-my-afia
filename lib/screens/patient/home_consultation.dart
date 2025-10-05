import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:async'; // Import pour TimeoutException et autres fonctionnalités async
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/services.dart'; // Ajout pour PlatformException
import 'package:permission_handler/permission_handler.dart' as perm_handler; // Alias pour éviter conflit avec Geolocator.LocationPermission
import 'package:flutter/foundation.dart' show kIsWeb; // Import for kIsWeb
import 'package:flutter_sound/flutter_sound.dart'; // Import pour l'enregistrement vocal
import 'package:path_provider/path_provider.dart'; // Pour getTemporaryDirectory
// Assurez-vous que le chemin d'importation vers votre page de paiement est correct
import 'package:google_fonts/google_fonts.dart'; // Importation de Google Fonts


enum AddressInputType { automatic, manual }

const String addressInputAutomatic = 'Utiliser ma position actuelle';
const String addressInputManual = 'Saisir l\'adresse manuellement';

class HomeConsultationPage extends StatefulWidget {
  const HomeConsultationPage({super.key});

  @override
  State<HomeConsultationPage> createState() => _HomeConsultationPageState();
}

class _HomeConsultationPageState extends State<HomeConsultationPage> {
  final List<Symptom> _symptoms = [
    Symptom(name: 'Fièvre', isChecked: false),
    Symptom(name: 'Toux', isChecked: false),
    Symptom(name: 'Maux de tête', isChecked: false),
    Symptom(name: 'Nausées', isChecked: false),
    Symptom(name: 'Fatigue', isChecked: false),
    Symptom(name: 'Douleurs musculaires', isChecked: false),
    Symptom(name: 'Perte d\'appétit', isChecked: false),
    Symptom(name: 'Frissons', isChecked: false),
    Symptom(name: 'Autres symptômes', isChecked: false, isOther: true),
  ];

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _manualAddressController = TextEditingController();
  // Nouveaux contrôleurs pour l'adresse détaillée
  final TextEditingController _quartierController = TextEditingController();
  final TextEditingController _communeController = TextEditingController();
  final TextEditingController _avenueController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _descriptionMaisonController = TextEditingController();


  Position? _currentPosition;
  String? _automaticAddress;
  bool _isFetchingLocation = false;
  AddressInputType _addressInputType = AddressInputType.automatic;

  final List<XFile> _imageFiles = []; // Store XFile objects
  String? _audioPath;
  bool _isRecording = false;
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();
  final ImagePicker _picker = ImagePicker();
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder(); // Instance pour l'enregistrement vocal

  List<String> _availableCities = [];
  String? _selectedCity;
  bool _isLoadingCities = true;
  DateTime? _lastSubmissionTime;

  @override
  void initState() {
    super.initState();
    _initRecorder(); // Initialiser l'enregistreur
    _loadAvailableCities().then((_) {
      if (mounted && _addressInputType == AddressInputType.automatic) {
        _initializeAutomaticLocation();
      }
    });
  }

  Future<void> _initRecorder() async {
    await _audioRecorder.openRecorder();
    await _audioPlayer.openPlayer();
  }

  Future<void> _initializeAutomaticLocation() async {
    if (_addressInputType == AddressInputType.automatic) {
      try {
        print("[DEBUG] _initializeAutomaticLocation: Initialisation de la localisation automatique...");
      await _requestLocationPermissionAndFetch();
      } catch (e) {
        print("[DEBUG] _initializeAutomaticLocation: Erreur lors de l'initialisation: $e");
        if (mounted) {
          setState(() {
            _automaticAddress = "Erreur lors de l'initialisation de la localisation.";
            _isFetchingLocation = false;
          });
        }
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    print("[DEBUG] _getCurrentLocation: Début de la récupération de la position.");
    if (!mounted) return;
    setState(() { _isFetchingLocation = true; });

    try {
      // Vérifier d'abord si les services de localisation sont activés
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("[DEBUG] _getCurrentLocation: Services de localisation désactivés.");
      if (mounted) {
        setState(() {
          _automaticAddress = "Services de localisation désactivés.";
            _isFetchingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: const Text('Les services de localisation sont désactivés. Veuillez les activer.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(label: 'Paramètres', onPressed: () => Geolocator.openLocationSettings()),
          ),
        );
      }
      return;
    }

      // Vérifier les permissions
    LocationPermission permission = await Geolocator.checkPermission();
      print("[DEBUG] _getCurrentLocation: Permission actuelle: $permission");
      
     if (permission == LocationPermission.denied) {
        print("[DEBUG] _getCurrentLocation: Permission refusée, demande de permission...");
        permission = await Geolocator.requestPermission();
        print("[DEBUG] _getCurrentLocation: Permission après demande: $permission");
    }

    if (permission == LocationPermission.deniedForever) {
        print("[DEBUG] _getCurrentLocation: Permission de localisation refusée définitivement.");
      if (mounted) {
        setState(() {
            _automaticAddress = "Permission de localisation refusée définitivement.";
            _isFetchingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permissions de localisation refusées définitivement. Modifiez-les dans les paramètres de l\'application.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(label: 'Paramètres', onPressed: () => Geolocator.openAppSettings()),
          ),
        );
      }
      return;
    }

      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        print("[DEBUG] _getCurrentLocation: Permission insuffisante: $permission");
        if (mounted) {
          setState(() {
            _automaticAddress = "Permission de localisation insuffisante.";
            _isFetchingLocation = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission de localisation insuffisante.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Tentative de récupération de la position
      print("[DEBUG] _getCurrentLocation: Tentative d'obtention de la position...");
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20) // Augmentation du timeout
      );
      
      print("[DEBUG] _getCurrentLocation: Coordonnées obtenues: Lat ${position.latitude}, Lon ${position.longitude}");
      
      // Utilisation directe des coordonnées GPS pour éviter les erreurs de géocodage
      print("[DEBUG] _getCurrentLocation: Création d'une adresse GPS basique...");
      
      String basicAddress = _createBasicAddressFromCoordinates(position.latitude, position.longitude);
      
        if (!mounted) return;
      
      print("[DEBUG] _getCurrentLocation: Adresse GPS créée: $basicAddress");
        setState(() {
          _currentPosition = position;
        _automaticAddress = basicAddress;
        _isFetchingLocation = false;
      });
      
      print("[DEBUG] _getCurrentLocation: Position et adresse GPS enregistrées avec succès.");
      
      // Tentative optionnelle de géocodage en arrière-plan (sans bloquer l'interface)
      _tryGeocodingInBackground(position.latitude, position.longitude);

    } on TimeoutException catch (e) {
      print("[DEBUG] _getCurrentLocation: Timeout lors de la récupération de la position: $e");
      if (mounted) {
        setState(() {
          _automaticAddress = "Impossible d'obtenir la position (timeout). Vérifiez votre signal GPS.";
          _isFetchingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de récupérer la position (timeout). Vérifiez votre signal GPS et réessayez.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on LocationServiceDisabledException catch (e) { 
        print("[DEBUG] _getCurrentLocation: LocationServiceDisabledException: $e");
        if (mounted) {
            setState(() {
                _automaticAddress = "Services de localisation désactivés.";
          _isFetchingLocation = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: const Text('Les services de localisation ont été désactivés.'),
                    backgroundColor: Colors.orange,
                    action: SnackBarAction(label: 'Activer', onPressed: () => Geolocator.openLocationSettings()),
                ),
            );
        }
    } on PlatformException catch (e) {
      print("[DEBUG] _getCurrentLocation: PlatformException - Code: ${e.code}, Message: ${e.message}");
      if (mounted) {
        setState(() {
          _currentPosition = null;
          _automaticAddress = "Erreur de plateforme: ${e.message ?? 'Impossible de récupérer la position.'}";
          _isFetchingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de plateforme (${e.code}): ${e.message ?? 'Détail non disponible'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("[DEBUG] _getCurrentLocation: Erreur inattendue: ${e.runtimeType} - $e");
      if (mounted) {
        setState(() {
          _currentPosition = null;
          _automaticAddress = "Erreur inattendue lors de la récupération de la position.";
          _isFetchingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur inattendue: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      print("[DEBUG] _getAddressFromCoordinates: Tentative de récupération d'adresse pour Lat: $latitude, Lon: $longitude");
      
      // Utilisation d'un timeout pour éviter les blocages
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 10));
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        print("[DEBUG] _getAddressFromCoordinates: Placemark récupéré avec succès");
        
        // Construction de l'adresse avec gestion ultra-sécurisée
        List<String> addressParts = [];
        
        // Vérification ultra-sécurisée de chaque champ
        _addSafeAddressPart(addressParts, place.street, "street");
        _addSafeAddressPart(addressParts, place.locality, "locality");
        _addSafeAddressPart(addressParts, place.postalCode, "postalCode");
        _addSafeAddressPart(addressParts, place.country, "country");
        
        // Construction de l'adresse finale
        if (addressParts.isNotEmpty) {
          String formattedAddress = addressParts.join(', ');
          print("[DEBUG] _getAddressFromCoordinates: Adresse formatée: $formattedAddress");
          return formattedAddress;
        } else {
          print("[DEBUG] _getAddressFromCoordinates: Aucune partie d'adresse valide trouvée");
          return null;
        }
      } else {
        print("[DEBUG] _getAddressFromCoordinates: Aucun placemark trouvé");
        return null;
      }
    } catch (e) {
      print("[DEBUG] _getAddressFromCoordinates: Erreur lors de la récupération de l'adresse: $e");
      return null;
    }
  }

  void _addSafeAddressPart(List<String> addressParts, String? value, String fieldName) {
    try {
      if (value != null && value.trim().isNotEmpty) {
        addressParts.add(value.trim());
        print("[DEBUG] _addSafeAddressPart: $fieldName ajouté: ${value.trim()}");
      }
    } catch (e) {
      print("[DEBUG] _addSafeAddressPart: Erreur avec $fieldName: $e");
    }
  }

  String _createBasicAddressFromCoordinates(double latitude, double longitude) {
    // Création d'une adresse basique à partir des coordonnées
    String latStr = latitude.toStringAsFixed(6);
    String lonStr = longitude.toStringAsFixed(6);
    
    // Détermination de la direction (N/S, E/W)
    String latDirection = latitude >= 0 ? 'N' : 'S';
    String lonDirection = longitude >= 0 ? 'E' : 'W';
    
    return "GPS: $latStr°$latDirection, $lonStr°$lonDirection";
  }

  Future<void> _loadAvailableCities() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCities = true;
    });
    try {
      print("[DEBUG] _loadAvailableCities: Tentative de chargement des villes depuis 'hopitaux/Villes'.");
      final citiesDocSnapshot = await FirebaseFirestore.instance
          .collection('hopitaux') 
          .doc('Villes')          
          .get();

      List<String> fetchedCityNames = [];
      if (citiesDocSnapshot.exists && citiesDocSnapshot.data() != null) {
        final data = citiesDocSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('cityNames') && data['cityNames'] is List) {
          fetchedCityNames = List<String>.from(data['cityNames']);
          print("[DEBUG] _loadAvailableCities: Noms de villes bruts récupérés: $fetchedCityNames");
        } else {
          print("[DEBUG] _loadAvailableCities: Le champ 'cityNames' est manquant ou n'est pas une liste dans 'hopitaux/Villes'.");
        }
      } else {
        print("[DEBUG] _loadAvailableCities: Le document 'hopitaux/Villes' n'existe pas.");
      }

      if (fetchedCityNames.isEmpty) {
        print("[DEBUG] _loadAvailableCities: Aucune ville trouvée.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune ville de service configurée pour le moment.'),
              backgroundColor: Colors.blue, 
            ),
          );
        }
      }

      final uniqueCities = fetchedCityNames.toSet().toList();
      uniqueCities.sort(); 
      print("[DEBUG] _loadAvailableCities: Villes uniques et triées: $uniqueCities");

      if (!mounted) return;
      setState(() {
        _availableCities = uniqueCities;
        _isLoadingCities = false;
      });
    } catch (e) {
      print("[DEBUG] _loadAvailableCities: Erreur lors du chargement des villes: $e");
      if (!mounted) return;
      setState(() {
        _isLoadingCities = false;
        _availableCities = []; 
      });
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des villes de service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _requestLocationPermissionAndFetch() async {
    if (!mounted) return;
    setState(() { _isFetchingLocation = true; });

    try {
      // Vérifier si les services de localisation sont activés
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("[DEBUG] _requestLocationPermissionAndFetch: Services de localisation désactivés.");
      if (mounted) {
        setState(() {
          _automaticAddress = "Services de localisation désactivés.";
          _isFetchingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Les services de localisation sont désactivés. Veuillez les activer.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Activer',
              onPressed: () {
                Geolocator.openLocationSettings();
              },
            ),
          ),
        );
      }
      return; 
    }

      // Vérifier et demander les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      print("[DEBUG] _requestLocationPermissionAndFetch: Permission actuelle: $permission");

      if (permission == LocationPermission.denied) {
        print("[DEBUG] _requestLocationPermissionAndFetch: Demande de permission...");
        permission = await Geolocator.requestPermission();
        print("[DEBUG] _requestLocationPermissionAndFetch: Permission après demande: $permission");
      }

      if (permission == LocationPermission.deniedForever) {
        print("[DEBUG] _requestLocationPermissionAndFetch: Permission refusée définitivement.");
        if (mounted) {
          setState(() {
            _automaticAddress = "Permission de localisation refusée définitivement.";
            _isFetchingLocation = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permissions de localisation refusées définitivement. Modifiez-les dans les paramètres de l\'application.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(label: 'Paramètres', onPressed: () => Geolocator.openAppSettings()),
            ),
          );
        }
        return;
      }

    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        print("[DEBUG] _requestLocationPermissionAndFetch: Permission accordée, récupération de la position...");
      await _getCurrentLocation(); 
    } else {
        print("[DEBUG] _requestLocationPermissionAndFetch: Permission insuffisante: $permission");
        if (mounted) {
        setState(() {
            _automaticAddress = "Permission de localisation insuffisante.";
          _isFetchingLocation = false;
        });
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: const Text('Permission de localisation nécessaire. Vous pouvez la modifier dans les paramètres de l\'application.'),
            backgroundColor: Colors.orange,
              action: SnackBarAction(label: 'Paramètres', onPressed: () => Geolocator.openAppSettings()),
            ),
          );
        }
      }
    } catch (e) {
      print("[DEBUG] _requestLocationPermissionAndFetch: Erreur: $e");
      if (mounted) {
        setState(() {
          _automaticAddress = "Erreur lors de la demande de permission.";
          _isFetchingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la demande de permission: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    print("[DEBUG] _pickImage: Tentative de sélection d'une image.");
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 70, 
    );

    if (pickedFiles.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _imageFiles.addAll(pickedFiles); 
        print("[DEBUG] _pickImage: Images sélectionnées: ${_imageFiles.length} fichiers.");
      });
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) {
      // Arrêter l'enregistrement
      try {
        final path = await _audioRecorder.stopRecorder();
        if (path != null) {
      setState(() {
            _isRecording = false;
            _audioPath = path;
          });
          print("[DEBUG] _startRecording: Enregistrement terminé. Fichier: $path");
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message vocal enregistré avec succès.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        print("[DEBUG] _startRecording: Erreur lors de l'arrêt de l'enregistrement: $e");
      setState(() {
        _isRecording = false;
      });
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'arrêt de l\'enregistrement: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Commencer l'enregistrement
      try {
        // Vérifier les permissions
        if (!kIsWeb && !await perm_handler.Permission.microphone.request().isGranted) {
      print("[DEBUG] _startRecording: Permission microphone refusée.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission microphone refusée. Impossible d\'enregistrer un message vocal.'),
            backgroundColor: Colors.red,
          ),
        );
      }
          return;
        }

        // Commencer l'enregistrement
        String filePath;
        if (kIsWeb) {
          // Pour le web, utiliser un nom de fichier simple
          filePath = 'web_audio.webm';
          await _audioRecorder.startRecorder(codec: Codec.opusWebM, toFile: filePath);
        } else {
          // Pour mobile, utiliser un chemin temporaire
          Directory? tempDir = await getTemporaryDirectory();
          filePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
          await _audioRecorder.startRecorder(toFile: filePath, codec: Codec.aacADTS);
        }

        setState(() {
          _isRecording = true;
        });
        print("[DEBUG] _startRecording: Enregistrement commencé.");
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enregistrement en cours... Appuyez à nouveau pour arrêter.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print("[DEBUG] _startRecording: Erreur lors du début de l'enregistrement: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors du début de l\'enregistrement: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _submitSymptoms() async {
    List<String> selectedSymptoms = _symptoms
        .where((symptom) => symptom.isChecked && !symptom.isOther)
        .map((symptom) => symptom.name)
        .toList();

    bool hasOtherSymptoms = _symptoms.any((s) => s.isOther && s.isChecked);
    String message = _messageController.text.trim();

    if (_lastSubmissionTime != null &&
        DateTime.now().difference(_lastSubmissionTime!) < const Duration(minutes: 5)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                  'Vous avez déjà soumis une demande récemment. Veuillez patienter 5 minutes avant de réessayer.')),
        );
      }
      return;
    }

    print("[DEBUG] _submitSymptoms: Symptômes sélectionnés: $selectedSymptoms");
    print("[DEBUG] _submitSymptoms: Autres symptômes: $hasOtherSymptoms");
    print("[DEBUG] _submitSymptoms: Message: '$message'");

    if (_selectedCity == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une ville pour la consultation.'),
          backgroundColor: Colors.orange, 
        ),
      );
      }
      return;
    }

    // Validation : au moins un symptôme ou des autres symptômes avec description
    if (selectedSymptoms.isEmpty && (!hasOtherSymptoms || (hasOtherSymptoms && message.isEmpty && _imageFiles.isEmpty && _audioPath == null))) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins un symptôme ou décrire vos autres symptômes.'),
          backgroundColor: Colors.orange, 
        ),
      );
      }
      return;
    }

    String? finalAddress;
    String? finalLocationCoordinates;

    if (_addressInputType == AddressInputType.automatic) {
      if (_currentPosition == null || _automaticAddress == null || _automaticAddress!.contains("non disponible") || _automaticAddress!.contains("refusée") || _automaticAddress!.contains("Impossible de déterminer")) {
        print("[DEBUG] _submitSymptoms: Adresse automatique invalide ou non disponible.");
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Veuillez fournir une adresse valide ou autoriser la localisation.'),
          backgroundColor: Colors.orange, 
        ));
        }
        return;
      }
      finalAddress = _automaticAddress;
      finalLocationCoordinates = 'Lat: ${_currentPosition!.latitude}, Lon: ${_currentPosition!.longitude}';
      print("[DEBUG] _submitSymptoms: Utilisation de l'adresse automatique: $finalAddress, Coordonnées: $finalLocationCoordinates");
    } else { 
      final quartier = _quartierController.text.trim();
      final commune = _communeController.text.trim();
      final avenue = _avenueController.text.trim();
      final numero = _numeroController.text.trim();
      final descriptionMaison = _descriptionMaisonController.text.trim();

      if (quartier.isEmpty || avenue.isEmpty || numero.isEmpty) {
        print("[DEBUG] _submitSymptoms: Champs d'adresse manuelle incomplets.");
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Veuillez remplir tous les champs d\'adresse (quartier, avenue, numéro).'),
          backgroundColor: Colors.orange, 
        ));
        }
        return;
      }
      finalAddress = "$avenue, N°$numero, $quartier";
      if (commune.isNotEmpty) finalAddress += ", $commune";
      finalAddress += ", $_selectedCity";
      
      // Ajouter la description de la maison si fournie
      if (descriptionMaison.isNotEmpty) {
        finalAddress += "\n\nDescription de la maison : $descriptionMaison";
      } 

      finalLocationCoordinates = null; 
      print("[DEBUG] _submitSymptoms: Utilisation de l'adresse manuelle: $finalAddress");
    }

    if (finalAddress == null || finalAddress.isEmpty) {
      print("[DEBUG] _submitSymptoms: Adresse finale manquante.");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('L\'adresse est requise.'),
        backgroundColor: Colors.orange, 
      ));
      }
      return;
    }
    print("[DEBUG] _submitSymptoms: Adresse finale à envoyer: $finalAddress");
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        Map<String, dynamic> consultationData = {
          'userId': user.uid,
          'symptoms': selectedSymptoms,
          'hasOtherSymptoms': hasOtherSymptoms,
          'message': message,
          'city': _selectedCity,
          'locationCoordinates': finalLocationCoordinates,
          'address': finalAddress,
        };

        print("[DEBUG] _submitSymptoms: Données préparées avant téléversement: $consultationData");

        List<String> imageUrls = [];
        String? audioUrl;

        if (_imageFiles.isNotEmpty) {
          imageUrls = await _uploadImages(user);
          consultationData['imageUrls'] = imageUrls;
        }
        if (_audioPath != null) {
          audioUrl = await _uploadAudio(user);
          consultationData['audioUrl'] = audioUrl;
        }

        consultationData['timestamp'] = FieldValue.serverTimestamp(); 
        consultationData['status'] = 'pending'; 

        print("[DEBUG] _submitSymptoms: Données finales à envoyer à Firestore: $consultationData");

        // Sauvegarder la consultation
        DocumentReference consultationRef = await FirebaseFirestore.instance.collection('home_consultations').add(consultationData);
        
        // Créer un message initial pour démarrer la conversation
        await _createInitialConsultationMessage(user.uid, consultationData, consultationRef.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande de consultation envoyée avec succès! Une conversation a été créée avec un médecin.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        setState(() {
          _lastSubmissionTime = DateTime.now();
        });
        _resetForm();
      } catch (e) {
        print("[DEBUG] _submitSymptoms: Error during data submission: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar( 
              content: Text('Erreur lors de l\'envoi de la demande: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print("[DEBUG] _submitSymptoms: Utilisateur non authentifié.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Utilisateur non authentifié. Veuillez vous reconnecter.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<String>> _uploadImages(User? currentUser) async {
    List<String> downloadUrls = [];
    for (XFile imageFile in _imageFiles) {
      try {
        String fileName = path.basename(imageFile.path);
        Reference storageRef = FirebaseStorage.instance.ref().child('consultation_images/${currentUser?.uid ?? 'unknown_user'}/$fileName');

        if (kIsWeb) {
          Uint8List fileBytes = await imageFile.readAsBytes();
          await storageRef.putData(fileBytes);
        } else {
          await storageRef.putFile(File(imageFile.path));
        }

        String downloadUrl = await storageRef.getDownloadURL();
        downloadUrls.add(downloadUrl);
      } catch (e) {
        print("[DEBUG] _uploadImages: Error uploading image: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors du téléversement d\'une image: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    return downloadUrls;
  }

  // Créer un message initial pour démarrer la conversation avec un médecin
  Future<void> _createInitialConsultationMessage(String patientId, Map<String, dynamic> consultationData, String consultationId) async {
    try {
      // Trouver un médecin disponible dans la ville sélectionnée
      String? assignedDoctorId = await _findAvailableDoctor(consultationData['city']);
      
      if (assignedDoctorId == null) {
        print("[DEBUG] _createInitialConsultationMessage: Aucun médecin disponible trouvé pour la ville ${consultationData['city']}");
        // Utiliser un médecin par défaut si aucun n'est trouvé dans la ville
        assignedDoctorId = 'TRITRiB31OgsMxFceg91hIAfjLW2'; // ID du médecin par défaut
      }

      // Créer le message initial avec les détails de la consultation
      String initialMessage = _buildInitialConsultationMessage(consultationData);
      
      // Ajouter le message à la collection messages
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': patientId,
        'receiverId': assignedDoctorId,
        'message': initialMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'consultation_request',
        'consultationId': consultationId,
        'city': consultationData['city'],
        'symptoms': consultationData['symptoms'],
        'hasOtherSymptoms': consultationData['hasOtherSymptoms'],
        'address': consultationData['address'],
        'imageUrls': consultationData['imageUrls'] ?? [],
        'audioUrl': consultationData['audioUrl'],
      });

      // Mettre à jour la consultation avec l'ID du médecin assigné
      await FirebaseFirestore.instance.collection('home_consultations').doc(consultationId).update({
        'assignedDoctorId': assignedDoctorId,
        'status': 'assigned',
      });

      print("[DEBUG] _createInitialConsultationMessage: Message initial créé avec le médecin $assignedDoctorId");
    } catch (e) {
      print("[DEBUG] _createInitialConsultationMessage: Erreur lors de la création du message initial: $e");
    }
  }

  // Trouver un médecin disponible dans une ville donnée
  Future<String?> _findAvailableDoctor(String city) async {
    try {
      // Chercher des médecins dans la ville spécifiée
      QuerySnapshot doctorsSnapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .where('city', isEqualTo: city)
          .where('isAvailable', isEqualTo: true)
          .limit(1)
          .get();

      if (doctorsSnapshot.docs.isNotEmpty) {
        return doctorsSnapshot.docs.first.id;
      }

      // Si aucun médecin dans cette ville, chercher des médecins disponibles en général
      QuerySnapshot generalDoctorsSnapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .where('isAvailable', isEqualTo: true)
          .limit(1)
          .get();

      if (generalDoctorsSnapshot.docs.isNotEmpty) {
        return generalDoctorsSnapshot.docs.first.id;
      }

      return null;
    } catch (e) {
      print("[DEBUG] _findAvailableDoctor: Erreur lors de la recherche de médecin: $e");
      return null;
    }
  }

  // Construire le message initial de consultation
  String _buildInitialConsultationMessage(Map<String, dynamic> consultationData) {
    StringBuffer message = StringBuffer();
    message.writeln("🩺 **Nouvelle demande de consultation**");
    message.writeln();
    message.writeln("📍 **Localisation:** ${consultationData['city']}");
    message.writeln("🏠 **Adresse:** ${consultationData['address']}");
    message.writeln();
    
    if (consultationData['symptoms'].isNotEmpty) {
      message.writeln("🩹 **Symptômes signalés:**");
      for (String symptom in consultationData['symptoms']) {
        message.writeln("• $symptom");
      }
      message.writeln();
    }
    
    if (consultationData['hasOtherSymptoms'] && consultationData['message'].isNotEmpty) {
      message.writeln("📝 **Description supplémentaire:**");
      message.writeln(consultationData['message']);
      message.writeln();
    }
    
    if (consultationData['imageUrls'] != null && (consultationData['imageUrls'] as List).isNotEmpty) {
      message.writeln("📷 **Images jointes:** ${(consultationData['imageUrls'] as List).length} image(s)");
    }
    
    if (consultationData['audioUrl'] != null) {
      message.writeln("🎤 **Message vocal joint**");
    }
    
    message.writeln();
    message.writeln("⏰ **Demande reçue le:** ${DateTime.now().toString().substring(0, 19)}");
    
    return message.toString();
  }

  Future<String?> _uploadAudio(User? currentUser) async {
    if (_audioPath == null) {
      print("[DEBUG] _uploadAudio: No audio file to upload.");
      return null;
    }
    try {
      String fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac'; 
      Reference storageRef = FirebaseStorage.instance.ref().child('consultation_audio/${currentUser?.uid ?? 'unknown_user'}/$fileName');

      if (kIsWeb) {
        // Sur le web, _audioPath est un chemin simulé, il faudrait une vraie gestion de fichier audio web
        // Pour l'instant, on ne peut pas directement lire un fichier local simulé de cette manière sur le web.
        // Cette partie nécessiterait une implémentation spécifique pour le web (ex: utiliser file_picker pour obtenir les bytes).
        print("[DEBUG] _uploadAudio: Audio upload for web from path is not directly supported with current simulation. Needs web-specific file handling.");
        return null; 
      } else {
        await storageRef.putFile(File(_audioPath!));
      }
      return await storageRef.getDownloadURL();
    } catch (e) {
      print("[DEBUG] _uploadAudio: Error uploading audio: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléversement du message vocal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _playAudio() async {
    if (_audioPath != null) {
      try {
        await _audioPlayer.startPlayer(fromURI: _audioPath!);
        print("[DEBUG] _playAudio: Lecture de l'audio: $_audioPath");
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lecture du message vocal...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print("[DEBUG] _playAudio: Erreur lors de la lecture: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la lecture: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _tryGeocodingInBackground(double latitude, double longitude) {
    // Tentative de géocodage en arrière-plan sans bloquer l'interface
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        print("[DEBUG] _tryGeocodingInBackground: Tentative de géocodage en arrière-plan...");
        String? detailedAddress = await _getAddressFromCoordinates(latitude, longitude);
        
        if (detailedAddress != null && mounted) {
          print("[DEBUG] _tryGeocodingInBackground: Adresse détaillée obtenue: $detailedAddress");
          setState(() {
            _automaticAddress = detailedAddress;
          });
          
          // Message supprimé car il gênait l'utilisateur
        }
      } catch (e) {
        print("[DEBUG] _tryGeocodingInBackground: Échec du géocodage en arrière-plan: $e");
        // Pas de message d'erreur car c'est optionnel
      }
    });
  }

  void _resetForm() {
    if (!mounted) return;
    
    // Arrêter l'enregistrement en cours si nécessaire
    if (_isRecording) {
      _audioRecorder.stopRecorder();
    }
    
    setState(() {
      for (var symptom in _symptoms) {
        symptom.isChecked = false;
      }
      _messageController.clear();
      _quartierController.clear();
      _communeController.clear();
      _avenueController.clear();
      _numeroController.clear();
      _descriptionMaisonController.clear();
      _imageFiles.clear(); 
      _audioPath = null;
      _isRecording = false;
    });
  }


  @override
  void dispose() {
    _messageController.dispose();
    _audioPlayer.closePlayer();
    _audioRecorder.closeRecorder(); // Fermer l'enregistreur
    _manualAddressController.dispose();
    _quartierController.dispose();
    _communeController.dispose();
    _avenueController.dispose();
    _numeroController.dispose();
    _descriptionMaisonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 800;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Consultation à domicile',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isDesktop ? 24 : 20,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: isDesktop 
        ? _buildDesktopLayout(theme)
        : _buildMobileLayout(theme),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
        child: Column( 
                crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  // En-tête avec icône
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.home_outlined,
                            size: 80,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Demande de consultation à domicile',
                          style: GoogleFonts.lato(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Remplissez le formulaire ci-dessous pour demander une consultation à domicile',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Section Ville et Adresse combinées
                  _buildSectionTitle('Localisation de consultation', Icons.location_on_outlined, theme),
                  const SizedBox(height: 16),
                  _buildLocationSection(theme),
                  const SizedBox(height: 32),

                  // Section Symptômes (avec bouton d'envoi inclus)
                  _buildSectionTitle('Symptômes', Icons.healing_outlined, theme),
                  const SizedBox(height: 16),
                  _buildSymptomsCardWithSubmit(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          // En-tête avec icône
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.home_outlined,
                    size: 60,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Demande de consultation à domicile',
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Remplissez le formulaire ci-dessous pour demander une consultation à domicile',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section Ville et Adresse combinées
          _buildSectionTitle('Localisation de consultation', Icons.location_on_outlined, theme),
          const SizedBox(height: 16),
          _buildLocationSection(theme),
          const SizedBox(height: 24),

          // Section Symptômes (avec bouton d'envoi inclus)
          _buildSectionTitle('Symptômes', Icons.healing_outlined, theme),
          const SizedBox(height: 16),
          _buildSymptomsCardWithSubmit(theme),
        ],
      ),
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

  Widget _buildSymptomsGrid(ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sélectionnez vos symptômes :',
              style: GoogleFonts.lato(
                fontSize: isDesktop ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_symptoms.length, (index) {
              final symptom = _symptoms[index];
              return Column(
                children: [
                  CheckboxListTile(
                    title: Text(
                      symptom.name,
                      style: GoogleFonts.roboto(
                        fontSize: isDesktop ? 16 : 15,
                        fontWeight: FontWeight.w500,
                        color: symptom.isChecked ? Colors.blue.shade700 : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    value: symptom.isChecked,
                    onChanged: (bool? value) {
                      setState(() {
                        symptom.isChecked = value ?? false;
                      });
                    },
                    activeColor: Colors.blue.shade700,
                    checkColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (index < _symptoms.length - 1) 
                    Divider(color: Colors.grey.shade300, height: 1),
                ],
              );
            }),
            // Interface pour "Autres symptômes"
            if (_symptoms.any((s) => s.isOther && s.isChecked)) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                        Icon(Icons.edit_note_outlined, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                                Text(
                          'Décrivez vos autres symptômes :',
                          style: GoogleFonts.lato(
                            fontSize: isDesktop ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      style: GoogleFonts.roboto(fontSize: isDesktop ? 15 : 14),
                                    decoration: InputDecoration(
                        hintText: 'Décrivez vos symptômes en détail...',
                        filled: true,
                        fillColor: Colors.white,
                                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.blue.shade200),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500, fontSize: isDesktop ? 14 : 13),
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: Icon(Icons.photo_library_outlined, color: Colors.white, size: 18),
                            label: Text('Photos', style: GoogleFonts.roboto(color: Colors.white, fontSize: isDesktop ? 14 : 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _startRecording,
                            icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 18),
                            label: Text(_isRecording ? 'Arrêter' : 'Audio', style: GoogleFonts.roboto(color: Colors.white, fontSize: isDesktop ? 14 : 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRecording ? Colors.red.shade600 : Colors.blue.shade600,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Affichage des images sélectionnées
                    if (_imageFiles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Images sélectionnées (${_imageFiles.length})',
                        style: GoogleFonts.roboto(
                          fontSize: isDesktop ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox( 
                        height: 80, 
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageFiles.length,
                          itemBuilder: (context, index) {
                            final imageFile = _imageFiles[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8), 
                                    child: kIsWeb
                                        ? FutureBuilder<Uint8List>(
                                            future: imageFile.readAsBytes(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  height: 80, 
                                                  width: 80,  
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return Container(
                                                height: 80, 
                                                width: 80, 
                                                color: theme.colorScheme.surface, 
                                                child: Center(child: CircularProgressIndicator(color: Colors.blue.shade700, strokeWidth: 2))
                                              );
                                            },
                                          )
                                        : Image.file(
                                            File(imageFile.path),
                                            height: 80, 
                                            width: 80,  
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.all(2), 
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _imageFiles.removeAt(index);
                                      });
                                    },
                                      child: const Padding(
                                        padding: EdgeInsets.all(2.0), 
                                        child: Icon(Icons.close_rounded, color: Colors.white, size: 14), 
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    // Affichage du message vocal
                    if (_audioPath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.multitrack_audio_rounded, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Message vocal enregistré',
                                  style: GoogleFonts.roboto(
                                    color: Colors.blue.shade700,
                                    fontSize: isDesktop ? 14 : 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _playAudio,
                                icon: Icon(Icons.play_arrow_rounded, color: Colors.blue.shade700, size: 20),
                                tooltip: 'Écouter le message',
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _audioPath = null;
                                  });
                                },
                                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 20),
                                tooltip: 'Supprimer le message',
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageSection(ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _messageController,
          style: GoogleFonts.roboto(fontSize: isDesktop ? 16 : 15),
          decoration: InputDecoration(
            hintText: 'Décrivez vos symptômes en détail...',
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintStyle: GoogleFonts.roboto(color: theme.colorScheme.onSurfaceVariant, fontSize: isDesktop ? 15 : 14.5),
          ),
          maxLines: isDesktop ? 6 : 4,
          textInputAction: TextInputAction.newline,
          minLines: isDesktop ? 4 : 3,
        ),
      ),
    );
  }

  Widget _buildAddressSection(ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                            if (_selectedCity != null) ...[
                            Row(
                              children: [
                  Icon(Icons.pin_drop_outlined, color: Colors.blue.shade700, size: isDesktop ? 28 : 24),
                  const SizedBox(width: 12),
                                Text(
                                  'Adresse pour la consultation',
                    style: GoogleFonts.lato(
                      fontSize: isDesktop ? 18 : 16, 
                      fontWeight: FontWeight.bold, 
                      color: theme.textTheme.titleMedium?.color
                    ),
                                ),
                              ],
                            ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                            RadioListTile<AddressInputType>(
                        title: Text(addressInputAutomatic, style: GoogleFonts.roboto(fontSize: isDesktop ? 16 : 15)),
                              value: AddressInputType.automatic,
                              groupValue: _addressInputType,
                              onChanged: (AddressInputType? value) {
                                if (value != null) {
                                  setState(() {
                                    _addressInputType = value;
                                    if (value == AddressInputType.automatic) {
                                      _initializeAutomaticLocation();
                                    }
                                  });
                                }
                              },
                              activeColor: Colors.blue.shade700,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<AddressInputType>(
                        title: Text(addressInputManual, style: GoogleFonts.roboto(fontSize: isDesktop ? 16 : 15)),
                              value: AddressInputType.manual,
                              groupValue: _addressInputType,
                              onChanged: (AddressInputType? value) {
                                if (value != null) {
                                  setState(() {
                                    _addressInputType = value;
                                  });
                                }
                              },
                              activeColor: Colors.blue.shade700,
                              contentPadding: EdgeInsets.zero,
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
                            if (_addressInputType == AddressInputType.automatic)
                Card(
                  elevation: 1,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                                child: _isFetchingLocation
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                              CircularProgressIndicator(strokeWidth: 3, color: Colors.blue.shade700),
                                          const SizedBox(width: 12),
                              Text("Recherche de la position...", style: GoogleFonts.roboto(color: theme.colorScheme.onSurfaceVariant)),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _automaticAddress ?? 'Aucune position obtenue.',
                                style: GoogleFonts.roboto(
                                  fontSize: isDesktop ? 15 : 14, 
                                  color: _automaticAddress == null || _automaticAddress!.contains("non disponible") || _automaticAddress!.contains("refusée") || _automaticAddress!.contains("Impossible de déterminer") 
                                    ? theme.colorScheme.onSurfaceVariant 
                                    : theme.textTheme.bodyMedium?.color
                                ),
                                          ),
                                          if (_automaticAddress == null || _automaticAddress!.contains("non disponible") || _automaticAddress!.contains("refusée") || _automaticAddress!.contains("Impossible de déterminer"))
                                            Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                              child: ElevatedButton.icon(
                                    icon: Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                                    label: Text("Obtenir ma position", style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.w500)),
                                                onPressed: _requestLocationPermissionAndFetch,
                                                style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                              ),
                                            ),
                                        ],
                          ),
                  ),
                )
              else
                Card(
                  elevation: 1,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                        _buildAddressTextField(_quartierController, 'Quartier *', 'Ex: Hay Mohammadi', theme, isDesktop),
                        const SizedBox(height: 12),
                        _buildAddressTextField(_communeController, 'Commune (optionnel)', 'Ex: Anfa', theme, isDesktop),
                        const SizedBox(height: 12),
                        _buildAddressTextField(_avenueController, 'Avenue/Rue/Boulevard *', 'Ex: Bd. Zerktouni', theme, isDesktop),
                        const SizedBox(height: 12),
                        _buildAddressTextField(_numeroController, 'Numéro de porte/immeuble *', 'Ex: N°15, Appt 3', theme, isDesktop),
                        const SizedBox(height: 12),
                        _buildHouseDescriptionField(theme, isDesktop),
                      ],
                    ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
    );
  }

  Widget _buildAddressTextField(TextEditingController controller, String label, String hint, ThemeData theme, bool isDesktop) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(color: theme.colorScheme.onSurfaceVariant, fontSize: isDesktop ? 16 : 15),
        floatingLabelStyle: GoogleFonts.roboto(color: Colors.blue.shade600),
        hintText: hint,
        hintStyle: GoogleFonts.roboto(color: theme.colorScheme.onSurfaceVariant, fontSize: isDesktop ? 15 : 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildHouseDescriptionField(ThemeData theme, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.home_outlined, color: Colors.blue.shade700, size: isDesktop ? 20 : 18),
            const SizedBox(width: 8),
            Text(
              'Description de la maison (optionnel)',
              style: GoogleFonts.roboto(
                fontSize: isDesktop ? 16 : 15,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionMaisonController,
          decoration: InputDecoration(
            labelText: 'Décrivez votre maison ou comment la localiser',
            labelStyle: GoogleFonts.roboto(color: theme.colorScheme.onSurfaceVariant, fontSize: isDesktop ? 15 : 14),
            floatingLabelStyle: GoogleFonts.roboto(color: Colors.blue.shade600),
            hintText: 'Ex: Maison blanche avec portail bleu, à côté de l\'école, 2ème étage, etc.',
            hintStyle: GoogleFonts.roboto(color: theme.colorScheme.onSurfaceVariant, fontSize: isDesktop ? 14 : 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection(ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                Icon(Icons.attach_file_outlined, color: Colors.blue.shade700, size: isDesktop ? 28 : 24),
                const SizedBox(width: 12),
                                Text(
                  'Ajouter des pièces jointes',
                                  style: GoogleFonts.lato(
                    fontSize: isDesktop ? 18 : 16, 
                                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color
                                  ),
                                ),
                              ],
                            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.photo_library_outlined, color: Colors.white),
                    label: Text('Photos', style: GoogleFonts.roboto(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white),
                    label: Text(_isRecording ? 'Arrêter' : 'Audio', style: GoogleFonts.roboto(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red.shade600 : Colors.blue.shade600,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
                    if (_imageFiles.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Images sélectionnées (${_imageFiles.length})',
                    style: GoogleFonts.roboto(
                      fontSize: isDesktop ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox( 
                    height: isDesktop ? 140 : 110, 
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imageFiles.length,
                            itemBuilder: (context, index) {
                              final imageFile = _imageFiles[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12), 
                                      child: kIsWeb
                                          ? FutureBuilder<Uint8List>(
                                              future: imageFile.readAsBytes(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                                  return Image.memory(
                                                    snapshot.data!,
                                              height: isDesktop ? 120 : 100, 
                                              width: isDesktop ? 120 : 100,  
                                                    fit: BoxFit.cover,
                                                  );
                                                }
                                          return Container(
                                            height: isDesktop ? 120 : 100, 
                                            width: isDesktop ? 120 : 100, 
                                            color: theme.colorScheme.surface, 
                                            child: Center(child: CircularProgressIndicator(color: Colors.blue.shade700, strokeWidth: 2.5))
                                          );
                                              },
                                            )
                                          : Image.file(
                                              File(imageFile.path),
                                        height: isDesktop ? 120 : 100, 
                                        width: isDesktop ? 120 : 100,  
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.all(3), 
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _imageFiles.removeAt(index);
                                          });
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(3.0), 
                                          child: Icon(Icons.close_rounded, color: Colors.white, size: 18), 
                                        ),
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

                    if (_audioPath != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: Chip( 
                    label: Text('Message vocal enregistré', style: GoogleFonts.roboto(color: theme.colorScheme.onSurfaceVariant)),
                            avatar: Icon(Icons.multitrack_audio_rounded, color: Colors.blue.shade700),
                    deleteIcon: Icon(Icons.cancel_outlined, color: theme.colorScheme.error),
                            onDeleted: () {
                              setState(() {
                                _audioPath = null;
                              });
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 56 : 50,
      child: ElevatedButton.icon(
        onPressed: _submitSymptoms,
        icon: Icon(Icons.send_rounded, size: isDesktop ? 24 : 22, color: Colors.white),
        label: Text(
          'Envoyer la demande de consultation',
          style: GoogleFonts.lato(
            fontSize: isDesktop ? 16 : 15,
            fontWeight: FontWeight.bold,
                color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildCitySection(ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_city_outlined, color: Colors.blue.shade700, size: isDesktop ? 28 : 24),
                const SizedBox(width: 12),
                Text(
                  'Ville de consultation',
                  style: GoogleFonts.lato(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            _isLoadingCities
                ? Center(child: CircularProgressIndicator(color: Colors.blue.shade700))
                : DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Sélectionnez une ville',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    value: _selectedCity,
                    hint: Text('Choisissez votre ville', style: GoogleFonts.roboto(color: theme.colorScheme.onSurfaceVariant)),
                    isExpanded: true,
                    items: _availableCities.map((String city) {
                      return DropdownMenuItem<String>(
                        value: city,
                        child: Text(city),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCity = newValue;
                        if (_addressInputType == AddressInputType.automatic) {
                          _automaticAddress = null; 
                          _currentPosition = null;  
                          if (_selectedCity != null) {
                            _initializeAutomaticLocation(); 
                          }
                        }
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez sélectionner une ville';
                      }
                      return null;
                    },
                    icon: Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.blue.shade600),
                    style: GoogleFonts.roboto(color: theme.textTheme.bodyMedium?.color, fontSize: isDesktop ? 16 : 15),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsCardWithSubmit(ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Text(
              'Sélectionnez vos symptômes et décrivez vos autres symptômes (optionnel) :',
              style: GoogleFonts.lato(
                fontSize: isDesktop ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_symptoms.length, (index) {
              final symptom = _symptoms[index];
              return Column(
                children: [
                  CheckboxListTile(
                    title: Text(
                      symptom.name,
                      style: GoogleFonts.roboto(
                        fontSize: isDesktop ? 16 : 15,
                        fontWeight: FontWeight.w500,
                        color: symptom.isChecked ? Colors.blue.shade700 : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    value: symptom.isChecked,
                    onChanged: (bool? value) {
                      setState(() {
                        symptom.isChecked = value ?? false;
                      });
                    },
                    activeColor: Colors.blue.shade700,
                    checkColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (index < _symptoms.length - 1) 
                    Divider(color: Colors.grey.shade300, height: 1),
                ],
              );
            }),
            const SizedBox(height: 20),
            // Interface pour "Autres symptômes"
            if (_symptoms.any((s) => s.isOther && s.isChecked)) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_note_outlined, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Décrivez vos autres symptômes :',
                          style: GoogleFonts.lato(
                            fontSize: isDesktop ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      style: GoogleFonts.roboto(fontSize: isDesktop ? 15 : 14),
                      decoration: InputDecoration(
                        hintText: 'Décrivez vos symptômes en détail...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                      ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500, fontSize: isDesktop ? 14 : 13),
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: Icon(Icons.photo_library_outlined, color: Colors.white, size: 18),
                            label: Text('Photos', style: GoogleFonts.roboto(color: Colors.white, fontSize: isDesktop ? 14 : 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _startRecording,
                            icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 18),
                            label: Text(_isRecording ? 'Arrêter' : 'Audio', style: GoogleFonts.roboto(color: Colors.white, fontSize: isDesktop ? 14 : 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRecording ? Colors.red.shade600 : Colors.blue.shade600,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Affichage des images sélectionnées
                    if (_imageFiles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Images sélectionnées (${_imageFiles.length})',
                        style: GoogleFonts.roboto(
                          fontSize: isDesktop ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox( 
                        height: 80, 
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageFiles.length,
                          itemBuilder: (context, index) {
                            final imageFile = _imageFiles[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8), 
                                    child: kIsWeb
                                        ? FutureBuilder<Uint8List>(
                                            future: imageFile.readAsBytes(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  height: 80, 
                                                  width: 80,  
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return Container(
                                                height: 80, 
                                                width: 80, 
                                                color: theme.colorScheme.surface, 
                                                child: Center(child: CircularProgressIndicator(color: Colors.blue.shade700, strokeWidth: 2))
                                              );
                                            },
                                          )
                                        : Image.file(
                                            File(imageFile.path),
                                            height: 80, 
                                            width: 80,  
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.all(2), 
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _imageFiles.removeAt(index);
                                        });
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(2.0), 
                                        child: Icon(Icons.close_rounded, color: Colors.white, size: 14), 
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    // Affichage du message vocal
                    if (_audioPath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.multitrack_audio_rounded, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Message vocal enregistré',
                                  style: GoogleFonts.roboto(
                                    color: Colors.blue.shade700,
                                    fontSize: isDesktop ? 14 : 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _playAudio,
                                icon: Icon(Icons.play_arrow_rounded, color: Colors.blue.shade700, size: 20),
                                tooltip: 'Écouter le message',
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _audioPath = null;
                                  });
                                },
                                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 20),
                                tooltip: 'Supprimer le message',
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Bouton d'envoi toujours visible
            Container(
              width: double.infinity,
              child: _buildSubmitButton(theme),
            ),
          ],
        ),
      ), 
    );
  }

  Widget _buildLocationSection(ThemeData theme) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Ville
            Row(
              children: [
                Icon(Icons.location_city_outlined, color: Colors.blue.shade700, size: isDesktop ? 28 : 24),
                const SizedBox(width: 12),
                Text(
                  'Ville de consultation',
                  style: GoogleFonts.lato(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _isLoadingCities
                ? Center(child: CircularProgressIndicator(color: Colors.blue.shade700))
                : DropdownButtonFormField<String>(
      decoration: InputDecoration(
                      labelText: 'Sélectionnez une ville',
                      labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade200),
        ),
        focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        filled: true,
                      fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
                    value: _selectedCity,
                    hint: Text('Choisissez votre ville', style: GoogleFonts.roboto(color: theme.colorScheme.onSurfaceVariant)),
                    isExpanded: true,
                    items: _availableCities.map((String city) {
                      return DropdownMenuItem<String>(
                        value: city,
                        child: Text(city),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCity = newValue;
                        if (_addressInputType == AddressInputType.automatic) {
                          _automaticAddress = null; 
                          _currentPosition = null;  
                          if (_selectedCity != null) {
                            _initializeAutomaticLocation(); 
                          }
                        }
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez sélectionner une ville';
                      }
                      return null;
                    },
                    icon: Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.blue.shade600),
                    style: GoogleFonts.roboto(color: theme.textTheme.bodyMedium?.color, fontSize: isDesktop ? 16 : 15),
                  ),
            
            // Section Adresse (si ville sélectionnée)
            if (_selectedCity != null) ...[
              const SizedBox(height: 24),
              Divider(color: Colors.grey.shade300, thickness: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.pin_drop_outlined, color: Colors.blue.shade700, size: isDesktop ? 28 : 24),
                  const SizedBox(width: 12),
                  Text(
                    'Adresse pour la consultation',
                    style: GoogleFonts.lato(
                      fontSize: isDesktop ? 18 : 16, 
                      fontWeight: FontWeight.bold, 
                      color: theme.textTheme.titleMedium?.color
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      RadioListTile<AddressInputType>(
                        title: Text(addressInputAutomatic, style: GoogleFonts.roboto(fontSize: isDesktop ? 16 : 15)),
                        value: AddressInputType.automatic,
                        groupValue: _addressInputType,
                        onChanged: (AddressInputType? value) {
                          if (value != null) {
                            setState(() {
                              _addressInputType = value;
                              if (value == AddressInputType.automatic) {
                                _initializeAutomaticLocation();
                              }
                            });
                          }
                        },
                        activeColor: Colors.blue.shade700,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<AddressInputType>(
                        title: Text(addressInputManual, style: GoogleFonts.roboto(fontSize: isDesktop ? 16 : 15)),
                        value: AddressInputType.manual,
                        groupValue: _addressInputType,
                        onChanged: (AddressInputType? value) {
                          if (value != null) {
                            setState(() {
                              _addressInputType = value;
                            });
                          }
                        },
                        activeColor: Colors.blue.shade700,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_addressInputType == AddressInputType.automatic)
                Card(
                  elevation: 1,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _isFetchingLocation
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(strokeWidth: 3, color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Text("Recherche de la position...", style: GoogleFonts.roboto(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _automaticAddress ?? 'Aucune position obtenue.',
                                style: GoogleFonts.roboto(
                                  fontSize: isDesktop ? 15 : 14, 
                                  color: _automaticAddress == null || _automaticAddress!.contains("non disponible") || _automaticAddress!.contains("refusée") || _automaticAddress!.contains("Impossible de déterminer") 
                                    ? theme.colorScheme.onSurfaceVariant 
                                    : theme.textTheme.bodyMedium?.color
                                ),
                              ),
                              if (_automaticAddress == null || _automaticAddress!.contains("non disponible") || _automaticAddress!.contains("refusée") || _automaticAddress!.contains("Impossible de déterminer"))
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                                    label: Text("Obtenir ma position", style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.w500)),
                                    onPressed: _requestLocationPermissionAndFetch,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                )
              else
                Card(
                  elevation: 1,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildAddressTextField(_quartierController, 'Quartier *', 'Ex: Hay Mohammadi', theme, isDesktop),
                        const SizedBox(height: 12),
                        _buildAddressTextField(_communeController, 'Commune (optionnel)', 'Ex: Anfa', theme, isDesktop),
                        const SizedBox(height: 12),
                        _buildAddressTextField(_avenueController, 'Avenue/Rue/Boulevard *', 'Ex: Bd. Zerktouni', theme, isDesktop),
                        const SizedBox(height: 12),
                        _buildAddressTextField(_numeroController, 'Numéro de porte/immeuble *', 'Ex: N°15, Appt 3', theme, isDesktop),
                        const SizedBox(height: 12),
                        _buildHouseDescriptionField(theme, isDesktop),
                      ],
                    ),
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }
}

class Symptom {
  String name;
  bool isChecked;
  bool isOther; // Added for the "Autres symptômes" option

  Symptom({required this.name, this.isChecked = false, this.isOther = false});
}
