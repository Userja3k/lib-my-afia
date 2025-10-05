import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' show PdfColors;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:ui' as ui;

class OrdonnanceScreen extends StatefulWidget {
  const OrdonnanceScreen({super.key});

  @override
  _OrdonnanceScreenState createState() => _OrdonnanceScreenState();
}

class _OrdonnanceScreenState extends State<OrdonnanceScreen> {
  final TextEditingController _medicamentController = TextEditingController();
  final TextEditingController _posologieController = TextEditingController();
  final TextEditingController _hopitalController = TextEditingController();

  final List<Map<String, String>> _medicaments = [];

  String? _patientId;
  List<String> _villesList = [];
  String? _selectedVille;
  bool _isLoadingVilles = true;

  List<Map<String, String>> _hopitauxList = [];
  String? _selectedHopitalId;
  bool _isLoadingHopitaux = false;

  String? _doctorId;
  bool _isInitialized = false;

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // Méthode pour déterminer le type d'appareil
  String _getDeviceType(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < mobileBreakpoint) {
      return 'mobile';
    } else if (screenWidth < tabletBreakpoint) {
      return 'tablet';
    } else if (screenWidth < desktopBreakpoint) {
      return 'small_desktop';
    } else {
      return 'large_desktop';
    }
  }

  // Méthode pour obtenir la taille de police responsive
  double _getResponsiveFontSize(BuildContext context, {double baseSize = 16}) {
    String deviceType = _getDeviceType(context);
    switch (deviceType) {
      case 'mobile':
        return baseSize;
      case 'tablet':
        return baseSize * 1.1;
      case 'small_desktop':
        return baseSize * 1.2;
      case 'large_desktop':
        return baseSize * 1.3;
      default:
        return baseSize;
    }
  }

  // Méthode pour obtenir le padding responsive
  EdgeInsets _getResponsivePadding(BuildContext context) {
    String deviceType = _getDeviceType(context);
    switch (deviceType) {
      case 'mobile':
        return const EdgeInsets.all(16.0);
      case 'tablet':
        return const EdgeInsets.all(24.0);
      case 'small_desktop':
        return const EdgeInsets.all(32.0);
      case 'large_desktop':
        return const EdgeInsets.all(40.0);
      default:
        return const EdgeInsets.all(16.0);
    }
  }

  // Méthode pour obtenir la largeur maximale du contenu
  double? _getMaxContentWidth(BuildContext context) {
    String deviceType = _getDeviceType(context);
    double screenWidth = MediaQuery.of(context).size.width;
    
    switch (deviceType) {
      case 'mobile':
        return null;
      case 'tablet':
        return screenWidth * 0.9;
      case 'small_desktop':
        return screenWidth * 0.8;
      case 'large_desktop':
        return 1000;
      default:
        return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is String) {
        _patientId = arguments;
      }
      _isInitialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _doctorId = user.uid;
    }
    _fetchVilles();
  }

  Future<void> _fetchVilles() async {
    setState(() {
      _isLoadingVilles = true;
    });
    try {
      DocumentSnapshot villesDoc = await FirebaseFirestore.instance.collection('hopitaux').doc('Villes').get();
      if (villesDoc.exists && villesDoc.data() != null) {
        final data = villesDoc.data() as Map<String, dynamic>;
        final villes = List<String>.from(data['cityNames'] ?? []);
        setState(() {
          _villesList = villes;
          _isLoadingVilles = false;
        });
      } else {
        setState(() {
          _isLoadingVilles = false;
        });
      }
    } catch (e) {
      setState(() { _isLoadingVilles = false; });
    }
  }

  Future<void> _fetchHopitaux(String ville) async {
    setState(() {
      _isLoadingHopitaux = true;
      _hopitauxList = [];
      _selectedHopitalId = null;
      _hopitalController.clear();
    });
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('hopitaux').doc('Villes').collection(ville).get();
      List<Map<String, String>> hopitauxData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, 'nom': data['Nom'] as String};
      }).toList();

      setState(() {
        _hopitauxList = hopitauxData;
        _isLoadingHopitaux = false;
      });
    } catch (e) {
      setState(() { _isLoadingHopitaux = false; });
    }
  }

  void _ajouterMedicament() {
    if (_medicamentController.text.isNotEmpty && _posologieController.text.isNotEmpty) {
      setState(() {
        _medicaments.add({
          'medicament': _medicamentController.text,
          'posologie': _posologieController.text,
        });
      });
      _medicamentController.clear();
      _posologieController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir le nom du médicament et sa posologie.')),
      );
    }
  }

  void _supprimerMedicament(int index) {
    setState(() {
      _medicaments.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String deviceType = _getDeviceType(context);
    final bool isMobile = deviceType == 'mobile';
    final bool isDesktop = deviceType == 'small_desktop' || deviceType == 'large_desktop';
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          'Nouvelle Ordonnance',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: _getResponsiveFontSize(context, baseSize: 22),
          ),
        ),
        centerTitle: !isMobile,
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
      ),
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _getMaxContentWidth(context) ?? double.infinity,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: _getResponsivePadding(context),
                  child: isDesktop 
                    ? Card(
                        elevation: isDarkMode ? 8.0 : 4.0,
                        color: isDarkMode ? Colors.grey[850] : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _buildContent(),
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildContent(),
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildContent() {
    final String deviceType = _getDeviceType(context);
    final bool isDesktop = deviceType == 'small_desktop' || deviceType == 'large_desktop';
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return [
      // Section pour ajouter un médicament
      Card(
        elevation: isDarkMode ? 8.0 : 4.0,
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajouter un Médicament',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, baseSize: 20), 
                  fontWeight: FontWeight.bold, 
                  color: isDarkMode ? Colors.blue[300] : Colors.blueAccent[700]
                ),
              ),
              SizedBox(height: isDesktop ? 20.0 : 16.0),
              TextField(
                controller: _medicamentController,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: _getResponsiveFontSize(context, baseSize: 16),
                ),
                decoration: InputDecoration(
                  labelText: 'Nom du Médicament',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: _getResponsiveFontSize(context, baseSize: 14),
                  ),
                  prefixIcon: Icon(
                    Icons.medication_outlined, 
                    color: isDarkMode ? Colors.blue[300] : Colors.blueAccent[400]
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.blue[300]! : Colors.blueAccent[400]!,
                      width: 2.0,
                    ),
                  ),
                  filled: isDarkMode,
                  fillColor: isDarkMode ? Colors.grey[800] : Colors.transparent,
                ),
              ),
              SizedBox(height: isDesktop ? 16.0 : 12.0),
              TextField(
                controller: _posologieController,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: _getResponsiveFontSize(context, baseSize: 16),
                ),
                decoration: InputDecoration(
                  labelText: 'Posologie (ex: 1 comprimé, 2 fois par jour)',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: _getResponsiveFontSize(context, baseSize: 14),
                  ),
                  prefixIcon: Icon(
                    Icons.schedule_outlined, 
                    color: isDarkMode ? Colors.blue[300] : Colors.blueAccent[400]
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.blue[300]! : Colors.blueAccent[400]!,
                      width: 2.0,
                    ),
                  ),
                  filled: isDarkMode,
                  fillColor: isDarkMode ? Colors.grey[800] : Colors.transparent,
                ),
              ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(
                    Icons.add_circle_outline, 
                    color: Colors.white,
                    size: _getResponsiveFontSize(context, baseSize: 20),
                  ),
                  label: Text(
                    'Ajouter le Médicament',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, baseSize: 16),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: _ajouterMedicament,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? Colors.blue[600] : Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isDesktop ? 16.0 : 12.0, 
                      horizontal: isDesktop ? 24.0 : 16.0
                    ),
                    textStyle: TextStyle(
                      fontSize: _getResponsiveFontSize(context, baseSize: 16), 
                      fontWeight: FontWeight.w500
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    elevation: isDarkMode ? 4.0 : 2.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      SizedBox(height: isDesktop ? 32.0 : 24.0),

      // Section pour l'hôpital recommandé
      Card(
        elevation: isDarkMode ? 8.0 : 4.0,
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hôpital Recommandé',
                style: TextStyle(
                  fontSize: _getResponsiveFontSize(context, baseSize: 18), 
                  fontWeight: FontWeight.bold, 
                  color: isDarkMode ? Colors.blue[300] : Colors.blueAccent[700]
                ),
              ),
              SizedBox(height: isDesktop ? 16.0 : 12.0),
              // Étape 1: Sélectionner la ville
              if (_isLoadingVilles)
                Center(
                  child: CircularProgressIndicator(
                    color: isDarkMode ? Colors.blue[300] : Colors.blueAccent,
                  ),
                )
              else if (_villesList.isEmpty)
                Container(
                  padding: EdgeInsets.all(isDesktop ? 16.0 : 12.0),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.red[900] : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: isDarkMode ? Colors.red[700]! : Colors.red.shade200),
                  ),
                  child: Text(
                    "Aucune ville trouvée. Vérifiez que le document 'hopitaux/Villes' contient bien un champ 'cityNames' avec la liste des villes.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDarkMode ? Colors.red[200] : Colors.red.shade800, 
                      fontStyle: FontStyle.italic,
                      fontSize: _getResponsiveFontSize(context, baseSize: 14),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: _getResponsiveFontSize(context, baseSize: 16),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Choisir une ville',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: _getResponsiveFontSize(context, baseSize: 14),
                    ),
                    prefixIcon: Icon(
                      Icons.location_city, 
                      color: isDarkMode ? Colors.blue[300] : Colors.blueAccent[400]
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.blue[300]! : Colors.blueAccent[400]!,
                        width: 2.0,
                      ),
                    ),
                    filled: isDarkMode,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.transparent,
                  ),
                  value: _selectedVille,
                  hint: Text(
                    'Sélectionnez d\'abord une ville',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      fontSize: _getResponsiveFontSize(context, baseSize: 14),
                    ),
                  ),
                  isExpanded: true,
                  items: _villesList.map((String ville) {
                    return DropdownMenuItem<String>(
                      value: ville,
                      child: Text(
                        ville,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontSize: _getResponsiveFontSize(context, baseSize: 14),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? nouvelleVille) {
                    if (nouvelleVille != null && nouvelleVille != _selectedVille) {
                      setState(() {
                        _selectedVille = nouvelleVille;
                      });
                      _fetchHopitaux(nouvelleVille);
                    }
                  },
                ),
              SizedBox(height: isDesktop ? 16.0 : 12.0),
              // Étape 2: Sélectionner l'hôpital (dépendant de la ville)
              if (_selectedVille != null)
                if (_isLoadingHopitaux)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(isDesktop ? 12.0 : 8.0), 
                      child: CircularProgressIndicator(
                        color: isDarkMode ? Colors.blue[300] : Colors.blueAccent,
                      ),
                    ),
                  )
                else if (_hopitauxList.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: isDesktop ? 12.0 : 8.0),
                      child: Text(
                        "Aucun hôpital trouvé pour $_selectedVille.", 
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[700], 
                          fontStyle: FontStyle.italic,
                          fontSize: _getResponsiveFontSize(context, baseSize: 14),
                        ),
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: _getResponsiveFontSize(context, baseSize: 16),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Choisir un hôpital (optionnel)',
                      labelStyle: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: _getResponsiveFontSize(context, baseSize: 14),
                      ),
                      prefixIcon: Icon(
                        Icons.local_hospital_outlined, 
                        color: isDarkMode ? Colors.blue[300] : Colors.blueAccent[400]
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.blue[300]! : Colors.blueAccent[400]!,
                          width: 2.0,
                        ),
                      ),
                      filled: isDarkMode,
                      fillColor: isDarkMode ? Colors.grey[800] : Colors.transparent,
                    ),
                    value: _selectedHopitalId,
                    hint: Text(
                      'Sélectionnez un hôpital dans $_selectedVille',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        fontSize: _getResponsiveFontSize(context, baseSize: 14),
                      ),
                    ),
                    isExpanded: true,
                    items: _hopitauxList.map((Map<String, String> hopital) {
                      return DropdownMenuItem<String>(
                        value: hopital['id'],
                        child: Text(
                          hopital['nom']!,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: _getResponsiveFontSize(context, baseSize: 14),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newId) {
                      setState(() {
                        _selectedHopitalId = newId;
                        final hopitalSelectionne = _hopitauxList.firstWhere((h) => h['id'] == newId, orElse: () => {'nom': ''});
                        _hopitalController.text = hopitalSelectionne['nom']!;
                      });
                    },
                  ),
            ],
          ),
        ),
      ),
      SizedBox(height: isDesktop ? 32.0 : 24.0),

      // Section pour la liste des médicaments
      if (_medicaments.isNotEmpty)
        Card(
          elevation: isDarkMode ? 8.0 : 4.0,
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Médicaments Ajoutés',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, baseSize: 18), 
                    fontWeight: FontWeight.bold, 
                    color: isDarkMode ? Colors.blue[300] : Colors.blueAccent[700]
                  ),
                ),
                SizedBox(height: isDesktop ? 16.0 : 10.0),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _medicaments.length,
                  itemBuilder: (context, index) {
                    final medicament = _medicaments[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: isDesktop ? 8.0 : 4.0),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                          width: 1.0,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 20.0 : 16.0,
                          vertical: isDesktop ? 8.0 : 4.0,
                        ),
                        leading: Icon(
                          Icons.medical_services_outlined, 
                          color: isDarkMode ? Colors.blue[300] : Colors.blueAccent[400],
                          size: _getResponsiveFontSize(context, baseSize: 24),
                        ),
                        title: Text(
                          medicament['medicament']!, 
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: _getResponsiveFontSize(context, baseSize: 16),
                          ),
                        ),
                        subtitle: Text(
                          medicament['posologie']!,
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: _getResponsiveFontSize(context, baseSize: 14),
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline, 
                            color: isDarkMode ? Colors.red[300] : Colors.red[400],
                            size: _getResponsiveFontSize(context, baseSize: 20),
                          ),
                          onPressed: () => _supprimerMedicament(index),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        )
      else
        Center(
          child: Container(
            padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1.0,
              ),
            ),
            child: Text(
              'Aucun médicament ajouté pour le moment.', 
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: _getResponsiveFontSize(context, baseSize: 16),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      
      SizedBox(height: isDesktop ? 40.0 : 30.0),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(
            Icons.receipt_long_outlined, 
            color: Colors.white,
            size: _getResponsiveFontSize(context, baseSize: 24),
          ),
          label: Text(
            'Générer l\'Ordonnance',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, baseSize: 18),
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fonctionnalité de génération d\'ordonnance en cours de développement')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkMode ? Colors.green[600] : Colors.green[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: isDesktop ? 20.0 : 15.0,
              horizontal: isDesktop ? 32.0 : 24.0,
            ),
            textStyle: TextStyle(
              fontSize: _getResponsiveFontSize(context, baseSize: 18), 
              fontWeight: FontWeight.bold
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            elevation: isDarkMode ? 8.0 : 5.0,
          ),
        ),
      ),
      SizedBox(height: isDesktop ? 32.0 : 20.0),
    ];
  }
}
