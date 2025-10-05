import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_virtuel/screens/settings/settings.dart';

class EmergencyPage extends StatefulWidget {
  final bool isDesktop;
  const EmergencyPage({super.key, this.isDesktop = false});

  @override
  _EmergencyPageState createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, dynamic>> _filteredHospitals = [];
  List<String> _cities = [];
  String? _selectedHospitalId;
  String? _selectedHospitalName;
  String? _selectedHospitalPhone;
  String? _selectedCity;
  final TextEditingController _citySearchController = TextEditingController();
  String _citySearchQuery = '';

  @override
  void initState() {
    super.initState();
    // _selectedCity est null par défaut, ce qui affichera le hint du DropdownButton.
    _loadHospitals();
    _citySearchController.addListener(_onCitySearchChanged);
  }

  // Fonction pour charger les hôpitaux et les villes depuis Firestore
  Future<void> _loadHospitals() async {
    setState(() {
      _isLoading = true;
      // Réinitialiser les sélections et listes lors du chargement/rechargement
      _selectedCity = null;
      _filteredHospitals.clear();
      _selectedHospitalId = null;
      _selectedHospitalName = null;
      _selectedHospitalPhone = null;
      _citySearchQuery = ''; // Réinitialiser la recherche de ville
      _citySearchController.clear(); // Vider le champ de recherche
    });

    try {
      if (!mounted) return; // Vérifier si le widget est toujours monté

      // 1. Charger la liste des villes depuis le document 'Villes'
      final citiesDocSnapshot = await FirebaseFirestore.instance
          .collection('hopitaux') // Collection principale
          .doc('Villes')          // Document qui contient les noms des villes
          .get();

      List<String> fetchedCityNames = [];
      if (citiesDocSnapshot.exists && citiesDocSnapshot.data() != null) {
        final data = citiesDocSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('cityNames') && data['cityNames'] is List) {
          fetchedCityNames = List<String>.from(data['cityNames']);
        }
        // print("Firestore fetched city names: $fetchedCityNames"); // Debug print
      }

      if (fetchedCityNames.isEmpty) {
        // print("Aucune ville trouvée dans hopitaux/Villes/cityNames"); // Debug print
        // Gérer le cas où aucune ville n'est listée
      }

      // Préparer la liste des villes pour le dropdown
      // Assurer l'unicité des noms de ville et les trier
      List<String> uniqueActualCities = fetchedCityNames.toSet().toList(); // Crée une liste de noms de ville uniques
      uniqueActualCities.sort(); // Trie les noms de ville par ordre alphabétique

      // Ajouter "Toutes les villes" au début de la liste
      _cities = ['Toutes les villes', ...uniqueActualCities];
      // print("Loaded cities: $_cities"); // Debug print
      // _selectedCity reste null initialement pour afficher le hint "Sélectionnez une ville"

      // _hospitals sera chargé dynamiquement lorsque _filterHospitalsByCity est appelé avec une ville sélectionnée.
      // Pour "Toutes les villes", nous devrons décider d'une stratégie (charger tout ou ne rien afficher par default).
      // Pour l'instant, "Toutes les villes" n'affichera rien jusqu'à ce qu'une ville spécifique soit choisie,
      // ou nous pourrions choisir de charger la première ville par default, ou ne rien faire.
      // Ici, nous allons simplement initialiser _filteredHospitals à vide.
      await _filterHospitalsByCity(loadHospitals: false); // Ne pas charger les hôpitaux initialement et s'assurer que setState est appelé

      if (!mounted) return;

    } catch (e) {
      print("Erreur lors du chargement des hôpitaux: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des villes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadHospitalsForCity(String cityName) async {
    if (cityName == 'Toutes les villes' || cityName.isEmpty) {
      // Pour "Toutes les villes", nous pourrions choisir de ne rien charger
      // ou de charger tous les hôpitaux de toutes les villes (ce qui est coûteux et non implémenté ici)
      // Pour cet exemple, nous allons vider la liste.
      setState(() {
        _hospitals.clear();
        _filteredHospitals.clear(); // Clear filtered list
        // Also reset hospital selection when city is "Toutes les villes" or empty
        _selectedHospitalId = null;
        _selectedHospitalName = null;
        _selectedHospitalPhone = null;
        // print("_loadHospitalsForCity('Toutes les villes'): Resetting hospital selection. _selectedHospitalName: $_selectedHospitalName"); // Debug print
      });
      return;
    }

    setState(() { _isLoading = true; });
    try {
      final hospitalsSnapshot = await FirebaseFirestore.instance
          .collection('hopitaux') // Collection principale
          .doc('Villes')          // Document 'Villes'
          .collection(cityName)   // Sous-collection nommée d'après la ville
          .get();

      _hospitals = hospitalsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'nom': data['Nom'] ?? 'Sans nom',
          'telephone': data['Phone'] ?? '',
          'ville': cityName, // La ville est connue car on charge depuis sa sous-collection
        };
      }).toList();
      _hospitals.sort((a, b) => a['nom'].compareTo(b['nom']));
      // print("Loaded ${_hospitals.length} hospitals for city: $cityName"); // Debug print
    } catch (e) {
      print("Erreur lors du chargement des hôpitaux pour $cityName: $e");
      _hospitals.clear(); // Vider en cas d'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des hôpitaux pour $cityName: $e')),
        );
      }
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
    // Note: _filteredHospitals will be updated in _filterHospitalsByCity after this future completes.
  }

  Future<void> _filterHospitalsByCity({bool loadHospitals = true}) async {
    // print("_filterHospitalsByCity called. Selected City: $_selectedCity, Load Hospitals: $loadHospitals"); // Debug print
    // No setState here, as the state updates will be inside the conditional blocks below
    if (_selectedCity == null) {
      _filteredHospitals = [];
    } else {
      if (loadHospitals) {
        await _loadHospitalsForCity(_selectedCity!);
      }
      // Après le chargement, _hospitals contient les hôpitaux de la ville sélectionnée (ou est vide si "Toutes les villes")
      // Donc, _filteredHospitals est juste une copie de _hospitals.
      _filteredHospitals = List.from(_hospitals);
    }
    // print("_filterHospitalsByCity finished. Filtered Hospitals Count: ${_filteredHospitals.length}"); // Debug print

    // Réinitialiser la sélection de l'hôpital si la liste filtrée est vide ou si l'hôpital sélectionné n'est plus dans la liste
    // Ou préserver la sélection si possible
    if (_filteredHospitals.isNotEmpty) {
      // Wrap state updates in setState
      setState(() {
        bool previousHospitalStillExists = _selectedHospitalId != null &&
            _filteredHospitals.any((h) => h['id'] == _selectedHospitalId);

        if (previousHospitalStillExists) {
          final hospital = _filteredHospitals.firstWhere((h) => h['id'] == _selectedHospitalId);
          _selectedHospitalName = hospital['nom']; // Update state
          _selectedHospitalPhone = hospital['telephone']; // Update state
          // print("$_filterHospitalsByCity: Preserving selection. _selectedHospitalName: $_selectedHospitalName"); // Debug print
        } else {
          // Sélectionner le premier hôpital par défaut si aucun n'était sélectionné ou si l'ancien n'existe plus
           if (_filteredHospitals.isNotEmpty) { // This check is redundant here
              _selectedHospitalId = _filteredHospitals[0]['id']; // Update state
              _selectedHospitalName = _filteredHospitals[0]['nom']; // Update state
              _selectedHospitalPhone = _filteredHospitals[0]['telephone']; // Update state
              // print("$_filterHospitalsByCity: Selecting first hospital. _selectedHospitalName: $_selectedHospitalName"); // Debug print with quotes
           } else {
              // This else block is unreachable if _filteredHospitals.isNotEmpty is true, but keeping for safety
              _selectedHospitalId = null; // Update state
              _selectedHospitalName = null; // Update state
              _selectedHospitalPhone = null; // Update state
              // print("$_filterHospitalsByCity: No hospitals found after filter (unexpected). Resetting selection. _selectedHospitalName: $_selectedHospitalName"); // Debug print
           }
        }
      }); // End setState
    } else {
      // Wrap state updates in setState
      setState(() {
            _selectedHospitalId = null;
            _selectedHospitalName = null;
            _selectedHospitalPhone = null;
            // print("$_filterHospitalsByCity: Filtered hospitals list is empty. Resetting selection. _selectedHospitalName: $_selectedHospitalName"); // Debug print
      }); // End setState
    }
    // No setState at the end, as state changes are handled within the conditional blocks
  }

  void _onCitySearchChanged() {
    setState(() {
      // print("setState called in _onCitySearchChanged"); // Debug print
      _citySearchQuery = _citySearchController.text.trim();
      List<String> currentFilteredCities = _filteredCities; // Appel au getter une fois

      if (currentFilteredCities.length == 1) {
        // Si une seule ville correspond à la recherche
        final uniqueFoundCity = currentFilteredCities.first;
        if (_selectedCity != uniqueFoundCity) {
          // Si la ville trouvée n'est pas déjà la ville sélectionnée, la mettre à jour
          _selectedCity = uniqueFoundCity;
          _filterHospitalsByCity(); // This call will now trigger setState internally
        }
      } else {
        // Plusieurs villes correspondent, ou aucune, ou la recherche est vide.
        // Si une ville était sélectionnée et qu'elle n'est plus dans les résultats filtrés actuels
        if (_selectedCity != null && !currentFilteredCities.contains(_selectedCity)) {
          // print("Selected city '$_selectedCity' filtered out by search. Resetting selection."); // Debug print
          _selectedCity = null;
          _filteredHospitals.clear(); // Clear filtered list
          _selectedHospitalId = null; // Reset hospital selection
          _selectedHospitalName = null; // Reset hospital selection
          _selectedHospitalPhone = null; // Reset hospital selection
          // Pas besoin d'appeler _filterHospitalsByCity() ici car _selectedCity est null,
          // la logique dans build() affichera "Veuillez sélectionner une ville..."
        }
        // Si _selectedCity est null, il reste null.
        // Si _selectedCity est non null et toujours dans currentFilteredCities, il reste sélectionné.
      }
      // print("City search query changed: '$_citySearchQuery', Filtered cities: ${currentFilteredCities.length}, Selected city is now: $_selectedCity"); // Debug print
    });
  }

  List<String> get _filteredCities {
    final query = _citySearchQuery.toLowerCase();
    final filtered = _cities.where((city) => city.toLowerCase().contains(query)).toList();
    // print("_filteredCities getter called. Query: '$query', Result count: ${filtered.length}, Cities: $filtered"); // Debug print
    return filtered;
  }

  // Fonction pour appeler un numéro
  Future<void> _callEmergency() async {
    if (_selectedHospitalPhone == null || _selectedHospitalPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        // This SnackBar should be shown if the button is pressed when phone is null/empty
        const SnackBar(content: Text('Aucun numéro de téléphone disponible')),
      );
      return;
    }

    final phoneNumber = 'tel:$_selectedHospitalPhone';

    // Vérifie si l'application peut lancer un appel téléphonique
    // Demande l'autorisation d'accéder aux appels (Android uniquement)
    /* PermissionStatus status = await Permission.phone.request(); // Commenté pour éviter une demande de permission potentiellement non gérée ici

    if (status.isGranted) {
      // Si l'autorisation est accordée, lance l'appel
      if (await canLaunch(phoneNumber)) {
        await launch(phoneNumber); // Lance l'appel
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lancer l\'appel')),
        );
      }
    } else {
      // Si l'autorisation est refusée, affiche un message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Autorisation d\'appel refusée')),
      );
    } */

    // Pour simplifier et éviter des problèmes de permission non gérés dans cet exemple,
    // nous allons directement tenter de lancer l'appel.
    // Dans une application de production, la gestion des permissions ci-dessus est recommandée.
    // print("Attempting to launch URL: $phoneNumber"); // Debug print
    try {
      if (await canLaunchUrl(Uri.parse(phoneNumber))) {
        // print("Launching URL: $phoneNumber"); // Debug print
        await launchUrl(Uri.parse(phoneNumber));
      } else {
        // print("Cannot launch URL: $phoneNumber"); // Debug print
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lancer l\'appel. Vérifiez si une application d\'appel est installée.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du lancement de l\'appel: $e')),
      );
    }
  }

  @override
  void dispose() {
    _citySearchController.removeListener(_onCitySearchChanged);
    _citySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: widget.isDesktop ? Colors.transparent : theme.scaffoldBackgroundColor,
      appBar: widget.isDesktop
          ? null
          : AppBar(
              title: Text('Urgences',
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 22,
                  )),
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
              systemOverlayStyle: SystemUiOverlayStyle.light,
              actions: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'settings') {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsPage()));
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'settings',
                      child: ListTile(
                          leading: Icon(Icons.settings), title: Text('Paramètres')),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  tooltip: 'Plus d\'options',
                )
              ],
            ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: Colors.blue.shade600))
            : RefreshIndicator(
                onRefresh: _loadHospitals,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildHeader(theme),
                    const SizedBox(height: 24),
                    _buildSelectionCard(theme),
                    const SizedBox(height: 32),
                    _buildCallButton(theme),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.1),
            border: Border.all(color: Colors.red.withOpacity(0.2), width: 2),
          ),
          child: Icon(
            Icons.emergency_outlined,
            size: 50,
            color: Colors.red.shade700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Appel d\'Urgence',
          style: GoogleFonts.lato(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.headlineMedium?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Sélectionnez un hôpital à contacter en cas d\'urgence.',
          style: GoogleFonts.roboto(
            fontSize: 16,
            color: theme.textTheme.bodyMedium?.color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSelectionCard(ThemeData theme) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepTitle(1, 'Choisir une ville', theme),
            const SizedBox(height: 12),
            TextField(
              controller: _citySearchController,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              decoration: InputDecoration(
                hintText: 'Rechercher une ville...',
                hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.blue.shade700),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: Colors.blue.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: Colors.blue.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                suffixIcon: _citySearchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: theme.textTheme.bodySmall?.color),
                        onPressed: () {
                          _citySearchController.clear();
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.location_city_outlined, color: Colors.blue.shade700),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: Colors.blue.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: Colors.blue.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant,
              ),
              style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w500),
              value: _selectedCity,
              hint: Text('Sélectionnez une ville', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
              isExpanded: true,
              items: _filteredCities.map((String city) {
                return DropdownMenuItem<String?>(
                  value: city,
                  child: Text(city),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  if (_citySearchController.text.isNotEmpty && newValue != _selectedCity) {
                    _citySearchController.clear();
                  }
                  _selectedCity = newValue;
                  _filterHospitalsByCity();
                });
              },
            ),
            if (_selectedCity != null && _selectedCity != 'Toutes les villes') ...[
              const SizedBox(height: 24),
              _buildStepTitle(2, 'Choisir un hôpital', theme),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
              else if (_filteredHospitals.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.local_hospital_outlined, color: Colors.blue.shade700),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Colors.blue.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Colors.blue.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant,
                  ),
                  style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w500),
                  value: _selectedHospitalId,
                  isExpanded: true,
                  hint: Text('Sélectionnez un hôpital', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                  items: _filteredHospitals.map((hospital) {
                    return DropdownMenuItem<String>(
                      value: hospital['id'],
                      child: Text(hospital['nom'], style: const TextStyle(overflow: TextOverflow.ellipsis)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    final selectedHospital = _filteredHospitals.firstWhere(
                        (hospital) => hospital['id'] == newValue,
                        orElse: () => <String, dynamic>{});
                    setState(() {
                      _selectedHospitalId = newValue;
                      _selectedHospitalName = selectedHospital['nom'];
                      _selectedHospitalPhone = selectedHospital['telephone'];
                    });
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Aucun hôpital trouvé pour "$_selectedCity".',
                      style: TextStyle(fontSize: 15, color: theme.textTheme.bodyMedium?.color, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepTitle(int step, String title, ThemeData theme) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.blue.shade700,
          child: Text(
            '$step',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.lato(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildCallButton(ThemeData theme) {
    bool canActuallyCall = _filteredHospitals.isNotEmpty &&
        _selectedHospitalPhone != null &&
        _selectedHospitalPhone!.isNotEmpty;

    String buttonLabelText;
    if (_selectedHospitalName != null) {
      buttonLabelText = 'Appeler ${_selectedHospitalName!}';
    } else {
      buttonLabelText = 'Appeler un Hôpital';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.call_rounded, color: Colors.white, size: 24),
          label: Text(
            buttonLabelText,
            style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: canActuallyCall ? Colors.red.shade600 : Colors.grey.shade400,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: canActuallyCall ? 5 : 0,
            shadowColor: Colors.red.withOpacity(0.4),
          ),
          onPressed: canActuallyCall ? _callEmergency : null,
        ),
        if (_selectedHospitalName != null && !canActuallyCall)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              'Le numéro de téléphone pour "${_selectedHospitalName!}" n\'est pas disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.red.shade400, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
