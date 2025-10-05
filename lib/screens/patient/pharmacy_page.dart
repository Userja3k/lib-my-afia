import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class PharmacyPage extends StatefulWidget {
  const PharmacyPage({Key? key}) : super(key: key);

  @override
  _PharmacyPageState createState() => _PharmacyPageState();
}

class _PharmacyPageState extends State<PharmacyPage> {
  bool _isLoading = true;
  bool _isDesktop = false;
  Position? _currentPosition;
  List<Map<String, dynamic>> _pharmacies = [];
  List<Map<String, dynamic>> _filteredPharmacies = [];
  TextEditingController _searchController = TextEditingController();
  double _maxDistance = 50.0;
  bool _showDistanceFilter = false;
  List<String> _cities = [];
  String? _selectedCity;
  bool _showCityFilter = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScreenSize();
    });
    _loadPharmacies();
    _loadCities();
    _getCurrentLocation();
  }

  void _checkScreenSize() {
    final mediaQuery = MediaQuery.of(context);
    setState(() {
      _isDesktop = mediaQuery.size.width >= 768;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Charger la liste des villes disponibles
  Future<void> _loadCities() async {
    try {
      final citiesSnapshot = await FirebaseFirestore.instance
          .collection('hopitaux')
          .doc('Villes')
          .get();

      if (citiesSnapshot.exists) {
        final data = citiesSnapshot.data();
        if (data != null && data['cityNames'] != null) {
          _cities = List<String>.from(data['cityNames']);
        }
      }

      setState(() {});
    } catch (e) {
      // En cas d'erreur, utiliser des données de test
      _cities = [
        'Goma', 'Bukavu', 'Kinshasa', 'Lubumbashi', 'Kisangani',
        'Mbuji-Mayi', 'Kananga', 'Mbandaka', 'Matadi', 'Boma'
      ];
      setState(() {});
    }
  }

  // Formater l'adresse en widgets Text séparés
  List<Widget> _formatAddressLines(Map<String, dynamic> pharmacy) {
    List<String> addressParts = [];
    
    if (pharmacy['ville'] != null && pharmacy['ville'].toString().isNotEmpty) {
      addressParts.add(pharmacy['ville']);
    }
    if (pharmacy['commune'] != null && pharmacy['commune'].toString().isNotEmpty) {
      addressParts.add('com. ${pharmacy['commune']}');
    }
    if (pharmacy['quartier'] != null && pharmacy['quartier'].toString().isNotEmpty) {
      addressParts.add(pharmacy['quartier']);
    }
    if (pharmacy['avenue'] != null && pharmacy['avenue'].toString().isNotEmpty) {
      addressParts.add('av. ${pharmacy['avenue']}');
    }
    if (pharmacy['numero'] != null && pharmacy['numero'].toString().isNotEmpty) {
      addressParts.add('n° ${pharmacy['numero']}');
    }
    
    if (addressParts.isEmpty) {
      addressParts.add(pharmacy['adresse'] ?? 'Adresse inconnue');
    }
    
    return [Text(addressParts.join(' '), style: TextStyle(color: Colors.grey.shade600, fontSize: 13))];
  }

  // Charger les pharmacies depuis Firestore
  Future<void> _loadPharmacies() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final pharmaciesSnapshot = await FirebaseFirestore.instance
          .collection('pharmacy')
          .get();

      _pharmacies = pharmaciesSnapshot.docs.map((doc) {
        final data = doc.data();
        final coordonnees = data['coordonnees'] as GeoPoint?;
        
        // Si pas de coordonnées, utiliser des coordonnées de test basées sur l'ID
        GeoPoint? finalCoordonnees = coordonnees;
        if (coordonnees == null) {
          final hash = doc.id.hashCode;
          final lat = -1.6636798 + (hash % 1000) / 10000.0;
          final lng = 29.19851 + (hash % 1000) / 10000.0;
          finalCoordonnees = GeoPoint(lat, lng);
        }
        
        return {
          'id': doc.id,
          'nom': data['nom']?.toString() ?? 'Sans nom',
          'adresse': data['adresse']?.toString() ?? 'Adresse inconnue',
          'ville': data['ville']?.toString() ?? '',
          'commune': data['commune']?.toString() ?? '',
          'quartier': data['quartier']?.toString() ?? '',
          'avenue': data['avenue']?.toString() ?? '',
          'numero': data['numero']?.toString() ?? '',
          'description': data['description']?.toString() ?? '',
          'coordonnees': finalCoordonnees,
          'distance': 0.0,
          'telephone': (data['contact'] as Map<String, dynamic>?)?.containsKey('telephone') == true 
              ? data['contact']['telephone']?.toString() ?? ''
              : data['telephone']?.toString() ?? '',
        };
      }).toList();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur de chargement des pharmacies')),
        );
      }
    } finally {
      _filterPharmacies();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Filtrer les pharmacies en fonction de la recherche et calculer les distances
  void _filterPharmacies() {
    List<Map<String, dynamic>> pharmaciesToProcess = List.from(_pharmacies);

    // Calculer les distances si la position est disponible
    if (_currentPosition != null) {
      for (var pharmacy in pharmaciesToProcess) {
        final coordonnees = pharmacy['coordonnees'] as GeoPoint?;
        
        if (coordonnees != null) {
          final latitude = coordonnees.latitude;
          final longitude = coordonnees.longitude;
          
          if (latitude != 0.0 && longitude != 0.0 && 
              latitude >= -90 && latitude <= 90 && 
              longitude >= -180 && longitude <= 180) {
            final distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              latitude,
              longitude,
            );
            pharmacy['distance'] = distance;
          } else {
            pharmacy['distance'] = -1.0;
          }
        } else {
          pharmacy['distance'] = -1.0;
        }
      }
      
      // Trier en mettant les pharmacies avec distance valide en premier
      pharmaciesToProcess.sort((a, b) {
        final distanceA = a['distance'] as double;
        final distanceB = b['distance'] as double;
        if (distanceA < 0 && distanceB < 0) return 0;
        if (distanceA < 0) return 1;
        if (distanceB < 0) return -1;
        return distanceA.compareTo(distanceB);
      });
    } else {
      for (var pharmacy in pharmaciesToProcess) {
        pharmacy['distance'] = -1.0;
      }
    }

    List<Map<String, dynamic>> currentlyFiltered = List.from(pharmaciesToProcess);

    // Filtrer par ville
    if (_selectedCity != null && _selectedCity!.isNotEmpty) {
      currentlyFiltered = currentlyFiltered.where((pharmacy) {
        final adresse = pharmacy['adresse'].toString().toLowerCase();
        return adresse.contains(_selectedCity!.toLowerCase());
      }).toList();
    }

    // Filtrer par distance maximale
    if (_showDistanceFilter && _currentPosition != null) {
      currentlyFiltered = currentlyFiltered.where((pharmacy) {
        final distance = pharmacy['distance'] as double;
        return distance >= 0 && distance <= (_maxDistance * 1000);
      }).toList();
    }

    // Filtrer en fonction de la recherche
    if (_searchController.text.isNotEmpty) {
      currentlyFiltered = currentlyFiltered.where((pharmacy) {
        return pharmacy['nom'].toString().toLowerCase().contains(_searchController.text.toLowerCase()) ||
               pharmacy['adresse'].toString().toLowerCase().contains(_searchController.text.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredPharmacies = currentlyFiltered;
    });
  }

  // Fonction temporaire pour ajouter des coordonnées de test aux pharmacies
  Future<void> _updatePharmaciesWithCoordinates() async {
    try {
      final pharmaciesSnapshot = await FirebaseFirestore.instance
          .collection('pharmacy')
          .get();

      for (var doc in pharmaciesSnapshot.docs) {
        final data = doc.data();
        final coordonnees = data['coordonnees'] as GeoPoint?;
        
        if (coordonnees == null) {
          final hash = doc.id.hashCode;
          final lat = -1.6636798 + (hash % 1000) / 10000.0;
          final lng = 29.19851 + (hash % 1000) / 10000.0;
          final newCoordonnees = GeoPoint(lat, lng);
          
          await FirebaseFirestore.instance
              .collection('pharmacy')
              .doc(doc.id)
              .update({
                'coordonnees': newCoordonnees,
              });
        }
      }
      
      _loadPharmacies();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 768 != _isDesktop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _isDesktop = constraints.maxWidth >= 768;
            });
          });
        }

        return Scaffold(
          appBar: _isDesktop ? null : AppBar(
            systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
            title: Text(
              'Pharmacies',
              style: GoogleFonts.lato(
                color: Colors.white,
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
            iconTheme: const IconThemeData(color: Colors.white),
          ),
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.98),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                  const SizedBox(height: 16),
                ],
              ),
            )
          : SingleChildScrollView( // Enveloppe le contenu principal pour le rendre défilable
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [

                      const SizedBox(height: 16),

                      // Barre de recherche de pharmacie
                       TextField(
                         controller: _searchController,
                         decoration: InputDecoration(
                           hintText: 'Rechercher une pharmacie...',
                           prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                           filled: true,
                           fillColor: Colors.white,
                           border: OutlineInputBorder(
                             borderRadius: BorderRadius.circular(25),
                             borderSide: BorderSide.none,
                           ),
                                                       suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.location_city, color: Colors.purple.shade700),
                                  tooltip: "Filtrer par ville",
                                  onPressed: () {
                                    setState(() {
                                      _showCityFilter = !_showCityFilter;
                                      if (!_showCityFilter) {
                                        _selectedCity = null;
                                        _filterPharmacies();
                                      }
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.radar, color: Colors.orange.shade700),
                                  tooltip: "Filtrer par distance",
                                  onPressed: () {
                                    setState(() {
                                      _showDistanceFilter = !_showDistanceFilter;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.my_location_rounded, color: Colors.blue.shade700),
                                  tooltip: "Utiliser ma position actuelle",
                                  onPressed: _getCurrentLocation,
                                ),
                              ],
                            ),
                         ),
                         onChanged: (value) {
                           _filterPharmacies();
                         },
                                               ),
                        // Filtre par ville
                        if (_showCityFilter)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sélectionner une ville',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedCity,
                                  decoration: InputDecoration(
                                    hintText: 'Choisir une ville...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: _cities.map((String city) {
                                    return DropdownMenuItem<String>(
                                      value: city,
                                      child: Text(city),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedCity = newValue;
                                    });
                                    _filterPharmacies();
                                  },
                                ),
                                if (_selectedCity != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Ville sélectionnée: $_selectedCity',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.purple.shade700,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _selectedCity = null;
                                            });
                                            _filterPharmacies();
                                          },
                                          child: Text(
                                            'Effacer',
                                            style: TextStyle(
                                              color: Colors.red.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        // Filtre de distance
                        if (_showDistanceFilter)
                         Container(
                           margin: const EdgeInsets.only(top: 12),
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(12),
                             border: Border.all(color: Colors.grey.shade300),
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   Text(
                                     'Rayon de recherche',
                                     style: TextStyle(
                                       fontWeight: FontWeight.bold,
                                       fontSize: 14,
                                       color: Colors.grey.shade800,
                                     ),
                                   ),
                                   Text(
                                     '${_maxDistance.toInt()} km',
                                     style: TextStyle(
                                       fontWeight: FontWeight.bold,
                                       fontSize: 14,
                                       color: Colors.blue.shade700,
                                     ),
                                   ),
                                 ],
                               ),
                               const SizedBox(height: 8),
                               SliderTheme(
                                 data: SliderTheme.of(context).copyWith(
                                   activeTrackColor: Colors.blue.shade700,
                                   inactiveTrackColor: Colors.grey.shade300,
                                   thumbColor: Colors.blue.shade700,
                                   overlayColor: Colors.blue.shade200,
                                   valueIndicatorColor: Colors.blue.shade700,
                                   valueIndicatorTextStyle: const TextStyle(
                                     color: Colors.white,
                                     fontSize: 12,
                                   ),
                                 ),
                                 child: Slider(
                                   value: _maxDistance,
                                   min: 1.0,
                                   max: 50.0,
                                   divisions: 49,
                                   label: '${_maxDistance.toInt()} km',
                                   onChanged: (value) {
                                     setState(() {
                                       _maxDistance = value;
                                     });
                                     _filterPharmacies();
                                   },
                                 ),
                               ),
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   Text(
                                     '1 km',
                                     style: TextStyle(
                                       fontSize: 12,
                                       color: Colors.grey.shade600,
                                     ),
                                   ),
                                   Text(
                                     '50 km',
                                     style: TextStyle(
                                       fontSize: 12,
                                       color: Colors.grey.shade600,
                                     ),
                                   ),
                                 ],
                               ),
                             ],
                           ),
                         ),
                    ],
                  ),
                ),
                                 // Messages informatifs
                 if (_searchController.text.isNotEmpty || _showDistanceFilter || _selectedCity != null)
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                     child: Column(
                                                children: [
                           if (_searchController.text.isNotEmpty)
                             Text(
                               'Pharmacies trouvées: ${_filteredPharmacies.length} (${_filteredPharmacies.length > 1 ? 's' : ''})',
                               style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 13),
                               textAlign: TextAlign.center,
                             ),
                           if (_selectedCity != null)
                             Text(
                               'Ville: $_selectedCity (${_filteredPharmacies.length} pharmacie${_filteredPharmacies.length > 1 ? 's' : ''} trouvée${_filteredPharmacies.length > 1 ? 's' : ''})',
                               style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade700, fontSize: 13),
                               textAlign: TextAlign.center,
                             ),
                           if (_showDistanceFilter && _currentPosition != null)
                             Text(
                               'Rayon de recherche: ${_maxDistance.toInt()} km (${_filteredPharmacies.length} pharmacie${_filteredPharmacies.length > 1 ? 's' : ''} trouvée${_filteredPharmacies.length > 1 ? 's' : ''})',
                               style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700, fontSize: 13),
                               textAlign: TextAlign.center,
                             ),
                         ],
                     ),
                   ),

                const SizedBox(height: 5),
                
                // Indicateur de statut de localisation
                if (_currentPosition == null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_off, color: Colors.orange.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Localisation non activée. Cliquez sur 📍 pour activer et voir les distances.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Retiré Expanded, car ListView fait maintenant partie de la Column défilable
                _filteredPharmacies.isEmpty
                    ? Padding( // Ajout d'un Padding pour l'état vide pour un meilleur espacement
                        padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 16.0),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty && _selectedCity != null
                                    ? 'Aucune pharmacie trouvée dans la ville de $_selectedCity.'
                                    : _searchController.text.isNotEmpty && _showDistanceFilter && _currentPosition != null
                                        ? 'Aucune pharmacie trouvée dans un rayon de ${_maxDistance.toInt()} km.'
                                        : _searchController.text.isNotEmpty
                                            ? 'Aucune pharmacie trouvée.'
                                            : _selectedCity != null
                                                ? 'Aucune pharmacie trouvée dans la ville de $_selectedCity.\nEssayez de changer de ville ou d\'élargir votre recherche.'
                                                : _showDistanceFilter && _currentPosition != null
                                                    ? 'Aucune pharmacie trouvée dans un rayon de ${_maxDistance.toInt()} km.\nEssayez d\'augmenter le rayon de recherche.'
                                                    : 'Aucune pharmacie trouvée.\nEssayez d\'élargir votre recherche ou de vérifier votre position.',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Actualiser"), onPressed: _loadPharmacies)
                            ],
                          ),
                        ),
                      )
                      : ListView.builder(
                          shrinkWrap: true, // Important pour ListView dans SingleChildScrollView
                          physics: const NeverScrollableScrollPhysics(), // Désactive son propre défilement
                          itemCount: _filteredPharmacies.length,
                          itemBuilder: (context, index) {
                            final pharmacy = _filteredPharmacies[index];
                            final double distanceValue = pharmacy['distance'] as double;
                            final String distanceText = distanceValue >= 0 
                                ? '${(distanceValue / 1000).toStringAsFixed(2)} km' 
                                : _currentPosition != null 
                                    ? 'Distance inconnue' 
                                    : 'Cliquez sur 📍 pour activer la localisation';
                            
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              clipBehavior: Clip.antiAlias,
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Icon(Icons.local_pharmacy_outlined, color: Colors.blue.shade700),
                                ),
                                title: Text(pharmacy['nom'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ..._formatAddressLines(pharmacy),
                                    Text(distanceText, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.directions_rounded, color: Colors.blue.shade600, size: 28),
                                      tooltip: "Itinéraire",
                                      onPressed: () {
                                        final coordonnees = pharmacy['coordonnees'] as GeoPoint?;
                                        if (coordonnees != null) {
                                          _openMaps(coordonnees.latitude, coordonnees.longitude);
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Coordonnées non disponibles pour cette pharmacie')),
                                          );
                                        }
                                      },
                                    ),
                                    // Icône téléphone pour toutes les pharmacies
                                    if (pharmacy['telephone'] != null && pharmacy['telephone'].isNotEmpty)
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.phone_rounded, color: Colors.green.shade600, size: 28),
                                        tooltip: "Contacter ${pharmacy['telephone']}",
                                        onSelected: (String choice) {
                                          if (choice == 'call') {
                                            _callPharmacy(pharmacy['telephone']);
                                          } else if (choice == 'whatsapp') {
                                            _openWhatsApp(pharmacy['telephone']);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          PopupMenuItem<String>(
                                            value: 'call',
                                            child: Row(
                                              children: [
                                                Icon(Icons.phone_rounded, color: Colors.green.shade600),
                                                const SizedBox(width: 8),
                                                const Text('Appeler'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'whatsapp',
                                            child: Row(
                                              children: [
                                                Icon(Icons.chat_bubble_outline, color: Colors.green.shade500),
                                                const SizedBox(width: 8),
                                                const Text('WhatsApp'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      IconButton(
                                        icon: Icon(Icons.phone_disabled_rounded, color: Colors.green.shade600, size: 28),
                                        tooltip: "Numéro de téléphone non disponible",
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Le numéro de téléphone de cette pharmacie n\'est pas disponible'),
                                              backgroundColor: Colors.black87,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                                childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                iconColor: Colors.blue,
                                collapsedIconColor: Colors.blueGrey,
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  if (pharmacy['description'] != null && pharmacy['description'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Text(
                                        'Description: ${pharmacy['description']}',
                                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  if (pharmacy['telephone'] != null && pharmacy['telephone'].isNotEmpty)
                                    Text('Téléphone: ${pharmacy['telephone']}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700))
                                  else
                                    Text('Téléphone: Non disponible', style: TextStyle(fontSize: 14, color: Colors.black87)),
                                ],
                              ),
                            );
                          },
                        ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Obtenir la position actuelle de l'utilisateur
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission de localisation refusée')),
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission de localisation refusée définitivement')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      _filterPharmacies();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'obtention de la position: $e')),
      );
    }
  }

  // Ouvrir l'application de navigation
  Future<void> _openMaps(double latitude, double longitude) async {
    try {
      // Essayer d'abord Google Maps avec l'application
      final Uri googleMapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving');
      
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: essayer avec le schéma Google Maps
        final Uri googleMapsSchemeUri = Uri.parse('google.navigation:q=$latitude,$longitude');
        if (await canLaunchUrl(googleMapsSchemeUri)) {
          await launchUrl(googleMapsSchemeUri, mode: LaunchMode.externalApplication);
        } else {
          // Fallback: essayer avec le schéma maps://
          final Uri mapsSchemeUri = Uri.parse('maps://app?daddr=$latitude,$longitude');
          if (await canLaunchUrl(mapsSchemeUri)) {
            await launchUrl(mapsSchemeUri, mode: LaunchMode.externalApplication);
          } else {
            // Fallback: essayer d'ouvrir dans le navigateur
            final Uri browserUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');
            if (await canLaunchUrl(browserUri)) {
              await launchUrl(browserUri, mode: LaunchMode.externalApplication);
            } else {
              throw Exception('Impossible d\'ouvrir la navigation');
            }
          }
        }
      }
    } catch (e) {
      print('Erreur Maps: $e'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture de la navigation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Appeler la pharmacie
  Future<void> _callPharmacy(String phoneNumber) async {
    try {
      // Nettoyer le numéro de téléphone
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Gérer les différents formats de numéros congolais
      if (cleanNumber.startsWith('+')) {
        // Numéro international déjà formaté
        cleanNumber = cleanNumber;
      } else if (cleanNumber.startsWith('243')) {
        // Numéro congolais sans +
        cleanNumber = '+$cleanNumber';
      } else if (cleanNumber.startsWith('0')) {
        // Numéro local congolais
        cleanNumber = '+243${cleanNumber.substring(1)}';
      } else if (cleanNumber.length == 9) {
        // Numéro congolais à 9 chiffres
        cleanNumber = '+243$cleanNumber';
      } else {
        // Autre format, essayer tel quel
        cleanNumber = '+$cleanNumber';
      }
      
      print('Numéro d\'appel formaté: $cleanNumber'); // Debug
      
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: cleanNumber,
      );
      
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Impossible de lancer l\'appel');
      }
    } catch (e) {
      print('Erreur appel: $e'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'appel de la pharmacie: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Ouvrir WhatsApp avec le numéro de téléphone
  Future<void> _openWhatsApp(String phoneNumber) async {
    try {
      // Nettoyer le numéro de téléphone
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Gérer les différents formats de numéros congolais
      if (cleanNumber.startsWith('+')) {
        // Numéro international déjà formaté
        cleanNumber = cleanNumber;
      } else if (cleanNumber.startsWith('243')) {
        // Numéro congolais sans +
        cleanNumber = '+$cleanNumber';
      } else if (cleanNumber.startsWith('0')) {
        // Numéro local congolais
        cleanNumber = '+243${cleanNumber.substring(1)}';
      } else if (cleanNumber.length == 9) {
        // Numéro congolais à 9 chiffres
        cleanNumber = '+243$cleanNumber';
      } else {
        // Autre format, essayer tel quel
        cleanNumber = '+$cleanNumber';
      }
      
      print('Numéro WhatsApp formaté: $cleanNumber'); // Debug
      
      // Essayer d'abord l'URL WhatsApp standard
      final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');
      
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: essayer avec le schéma whatsapp://
        final Uri whatsappSchemeUri = Uri.parse('whatsapp://send?phone=$cleanNumber');
        if (await canLaunchUrl(whatsappSchemeUri)) {
          await launchUrl(whatsappSchemeUri, mode: LaunchMode.externalApplication);
        } else {
          // Fallback: essayer d'ouvrir dans le navigateur
          final Uri browserUri = Uri.parse('https://web.whatsapp.com/send?phone=$cleanNumber');
          if (await canLaunchUrl(browserUri)) {
            await launchUrl(browserUri, mode: LaunchMode.externalApplication);
          } else {
            throw Exception('Impossible d\'ouvrir WhatsApp');
          }
        }
      }
    } catch (e) {
      print('Erreur WhatsApp: $e'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture de WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
