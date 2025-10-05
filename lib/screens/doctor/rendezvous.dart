import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_virtuel/screens/settings/settings.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class RendezvousPage extends StatefulWidget {
  final bool isDesktop;
  
  const RendezvousPage({super.key, this.isDesktop = false});

  @override
  _RendezvousPageState createState() => _RendezvousPageState();
}

class _RendezvousPageState extends State<RendezvousPage> {
  String _filter = "Tous";
  String _statusFilter = "Tous";
  final String? _doctorId = FirebaseAuth.instance.currentUser?.uid;

  Stream<QuerySnapshot> _getFilteredRendezvous() {
    if (_doctorId == null) {
      debugPrint("Erreur : Aucun médecin connecté.");
      return Stream.empty(); // Retourne un stream vide si _doctorId est null
    }

    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    DateTime startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    // Correction: endOfWeek doit être calculé à partir de startOfWeek pour couvrir toute la semaine
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    Query query = FirebaseFirestore.instance
        .collection('rendezvous')
        .where('doctorId', isEqualTo: _doctorId);

    if (_statusFilter != "Tous") {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    DateTime? startDate;
    DateTime? endDate;

    switch (_filter) {
      case "Aujourd'hui":
        startDate = startOfDay;
        endDate = endOfDay;
        break;
      case "Demain":
        startDate = startOfDay.add(const Duration(days: 1));
        endDate = startDate.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        break;
      case "Cette semaine":
        startDate = startOfWeek;
        endDate = endOfWeek;
        break;
      case "Passés":
        // Pour les rendez-vous passés, on cherche tout ce qui est avant maintenant
        endDate = now;
        break;
      case "Tous":
        // Pas de filtre de date spécifique, tous les rendez-vous sont inclus
    }

    if (startDate != null && endDate != null) {
      query = query
          .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('appointmentTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    else if (endDate != null && _filter == "Passés") {
      query = query.where('appointmentTime', isLessThan: Timestamp.fromDate(endDate));
    }

    query = query.orderBy('appointmentTime', descending: true); // Changé à true pour les plus récents en premier

    debugPrint("Filtre appliqué: $_filter, Statut: $_statusFilter, DoctorID: $_doctorId");
    return query.snapshots();
  }

  Future<void> _rescheduleRendezvous(String docId, DateTime currentAppointmentTime) async {
    // Vérifier si le rendez-vous est dans moins de 30 minutes
    if (currentAppointmentTime.difference(DateTime.now()).inMinutes < 30) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de décaler un rendez-vous moins de 30 minutes avant son heure.')),
        );
      }
      return; // Sortir de la fonction si la condition n'est pas remplie
    }

    final minutes = await showDialog<int>(
      context: context,
      builder: (context) {
        int delayMinutes = 0;
        final TextEditingController minutesController = TextEditingController();

        return AlertDialog(
          title: const Text('Décaler le rendez-vous'),
          content: TextField(
            controller: minutesController,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(
              labelText: 'Décalage en minutes',
              hintText: 'Positif pour reporter, négatif pour avancer',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              delayMinutes = int.tryParse(value) ?? 0;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null); // Ferme sans valeur
              },
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                if (delayMinutes != 0) { // Accepte les valeurs positives et négatives, mais pas zéro
                  Navigator.of(context).pop(delayMinutes);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez entrer un nombre de minutes non nul.')),
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (minutes != null && minutes != 0) {
      final newDateTime = currentAppointmentTime.add(Duration(minutes: minutes));
      final action = minutes > 0 ? 'repoussé' : 'avancé';

      try {
        await FirebaseFirestore.instance.collection('rendezvous').doc(docId).update({
          'appointmentTime': Timestamp.fromDate(newDateTime),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rendez-vous $action avec succès !')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors du report : ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _updateStatus(String docId, String currentStatus) async {
    final newStatus = currentStatus == 'Non confirmé' ? 'Confirmé' : 'Non confirmé';

    try {
      await FirebaseFirestore.instance.collection('rendezvous').doc(docId).update({
        'status': newStatus,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour : $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de mise à jour du statut : ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _sendAppointmentInfo(String docId, String patientId, DateTime appointmentTime, String status) async {
    await showDialog(
      context: context,
      builder: (context) => _AppointmentInfoDialog(
        docId: docId,
        patientId: patientId,
        appointmentTime: appointmentTime,
        status: status,
        doctorId: _doctorId!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Vérification initiale de _doctorId
    if (_doctorId == null) {
      return Scaffold( // Important d'avoir un Scaffold même pour l'erreur pour la cohérence de l'UI
        appBar: widget.isDesktop
            ? null // Pas d'AppBar en mode desktop
            : AppBar(
                systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                ),
                title: Text('Rendez-vous', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
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
              ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 60),
              SizedBox(height: 16),
              Text('Erreur : Aucun médecin connecté.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Veuillez vous reconnecter pour voir les rendez-vous.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: widget.isDesktop
          ? null // Pas d'AppBar en mode desktop
          : AppBar(
              systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
              title: Text(
                'Rendez-vous',
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
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  tooltip: "Options et filtres",
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5, // Limite la hauteur du menu et le rend scrollable si le contenu dépasse.
                  ),
                  onSelected: (String value) {
                    if (value.startsWith('period_')) {
                      setState(() {
                        _filter = value.substring('period_'.length);
                      });
                    } else if (value.startsWith('status_')) {
                      setState(() {
                        _statusFilter = value.substring('status_'.length);
                      });
                    } else if (value == 'settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text('Filtrer par période', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor)),
                    ),
                    ...["Tous", "Aujourd'hui", "Demain", "Cette semaine", "Passés"].map((String value) {
                      return CheckedPopupMenuItem<String>(value: 'period_$value', checked: _filter == value, child: Text(value));
                    }).toList(),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text('Filtrer par statut', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor)),
                    ),
                    ...["Tous", "Confirmé", "Non confirmé"].map((String value) {
                      return CheckedPopupMenuItem<String>(value: 'status_$value', checked: _statusFilter == value, child: Text(value));
                    }).toList(),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'settings',
                      child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Paramètres'), contentPadding: EdgeInsets.zero),
                    ),
                  ],
                ),
              ],
            ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getFilteredRendezvous(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text('Erreur : ${snapshot.error}', style: const TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun rendez-vous trouvé',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Filtre actuel : $_filter - Statut : $_statusFilter',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return widget.isDesktop
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Card(
                    elevation: 8,
                    margin: const EdgeInsets.all(32.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildRendezvousContent(snapshot.data!.docs),
                    ),
                  ),
                ),
              )
            : _buildRendezvousContent(snapshot.data!.docs);
        },
      ),
    );
  }

  Widget _buildRendezvousContent(List<QueryDocumentSnapshot> rendezvousDocs) {
    return ListView.builder(
      itemCount: rendezvousDocs.length,
      itemBuilder: (context, index) {
        final doc = rendezvousDocs[index];
        final data = doc.data() as Map<String, dynamic>;
        
        final appointmentTime = (data['appointmentTime'] as Timestamp).toDate();
        final patientId = data['userId'] ?? data['patientId']; // ID du patient
        final status = data['status'] ?? 'Non confirmé';
        final notes = data['notes'] as String?;
        
        final isPast = appointmentTime.isBefore(DateTime.now());
        final isToday = appointmentTime.day == DateTime.now().day &&
                       appointmentTime.month == DateTime.now().month &&
                       appointmentTime.year == DateTime.now().year;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: isPast 
                ? Colors.grey 
                : isToday 
                  ? Colors.orange 
                  : Colors.blue,
              child: Icon(
                isPast ? Icons.history : Icons.calendar_today,
                color: Colors.white,
              ),
            ),
            title: patientId != null 
              ? StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(patientId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final userData = snapshot.data!.data() as Map<String, dynamic>;
                      final prenom = userData['prenom']?.toString() ?? 
                                   userData['first_name']?.toString() ?? 
                                   'Patient inconnu';
                      return Text(
                        prenom,
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      );
                    } else {
                      return Text(
                        'Patient inconnu',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      );
                    }
                  },
                )
              : Text(
                  'Patient inconnu',
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM/yyyy à HH:mm').format(appointmentTime),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      status == 'Confirmé' ? Icons.check_circle : Icons.schedule,
                      size: 16,
                      color: status == 'Confirmé' ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: status == 'Confirmé' ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Notes: $notes',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            trailing: !isPast ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'reschedule':
                    _rescheduleRendezvous(doc.id, appointmentTime);
                    break;
                  case 'status':
                    _updateStatus(doc.id, status);
                    break;
                  case 'send_info':
                    _sendAppointmentInfo(doc.id, patientId, appointmentTime, status);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reschedule',
                  child: ListTile(
                    leading: Icon(Icons.schedule),
                    title: Text('Décaler'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'status',
                  child: ListTile(
                    leading: Icon(status == 'Confirmé' ? Icons.cancel : Icons.check_circle),
                    title: Text(status == 'Confirmé' ? 'Déconfirmer' : 'Confirmer'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'send_info',
                  child: ListTile(
                    leading: Icon(Icons.message),
                    title: Text('Envoyer les informations'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ) : null,
          ),
        );
      },
    );
  }
}

class _AppointmentInfoDialog extends StatefulWidget {
  final String docId;
  final String patientId;
  final DateTime appointmentTime;
  final String status;
  final String doctorId;

  const _AppointmentInfoDialog({
    required this.docId,
    required this.patientId,
    required this.appointmentTime,
    required this.status,
    required this.doctorId,
  });

  @override
  _AppointmentInfoDialogState createState() => _AppointmentInfoDialogState();
}

class _AppointmentInfoDialogState extends State<_AppointmentInfoDialog> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isLoadingLocation = false;
  String? _currentLocation;

  @override
  void dispose() {
    _addressController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Vérifier si les services de localisation sont activés
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Les services de localisation sont désactivés. Veuillez les activer.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission de localisation refusée définitivement. Modifiez-les dans les paramètres.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission de localisation insuffisante'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Obtenir la position actuelle avec un timeout plus long
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Convertir en adresse avec gestion d'erreur
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 10));

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          List<String> addressParts = [];
          
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            addressParts.add(place.postalCode!);
          }
          if (place.country != null && place.country!.isNotEmpty) {
            addressParts.add(place.country!);
          }

          String address = addressParts.join(', ');
          
          if (address.isNotEmpty) {
            setState(() {
              _currentLocation = address;
              _addressController.text = address;
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Position actuelle récupérée avec succès'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            // Fallback avec coordonnées GPS
            String gpsAddress = 'GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
            setState(() {
              _currentLocation = gpsAddress;
              _addressController.text = gpsAddress;
            });
          }
        } else {
          // Fallback avec coordonnées GPS
          String gpsAddress = 'GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          setState(() {
            _currentLocation = gpsAddress;
            _addressController.text = gpsAddress;
          });
        }
      } catch (geocodingError) {
        // Fallback avec coordonnées GPS si le géocodage échoue
        String gpsAddress = 'GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        setState(() {
          _currentLocation = gpsAddress;
          _addressController.text = gpsAddress;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Position GPS récupérée (adresse non disponible)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la récupération de la position: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _addCurrentLocationToAddress() async {
    if (_currentLocation == null) {
      // Récupérer la position actuelle d'abord
      await _getCurrentLocation();
    }
    
    if (_currentLocation != null) {
      String currentText = _addressController.text.trim();
      if (currentText.isNotEmpty) {
        _addressController.text = '$currentText\n\n📍 Position actuelle: $_currentLocation';
      } else {
        _addressController.text = '📍 Position actuelle: $_currentLocation';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position actuelle ajoutée à l\'adresse'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    // Vérifier si le rendez-vous est confirmé
    if (widget.status != 'Confirmé') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord confirmer le rendez-vous avant d\'envoyer les informations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir une adresse')),
      );
      return;
    }

    try {
      // Créer le message markdown
      String markdownMessage = _buildMarkdownMessage();
      
      // Envoyer le message au patient
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': widget.doctorId,
        'receiverId': widget.patientId,
        'message': markdownMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': 'text',
        'type': 'appointment_info',
        'appointmentId': widget.docId,
        'address': _addressController.text.trim(),
        'isCurrentLocation': _currentLocation != null && 
            (_addressController.text.trim() == _currentLocation || 
             _addressController.text.contains('Position actuelle')),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informations de rendez-vous envoyées avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi: $e')),
        );
      }
    }
  }

  String _buildMarkdownMessage() {
    String statusText = widget.status == 'Confirmé' ? '✅ CONFIRMÉ' : '⏰ EN ATTENTE';
    String timeText = DateFormat('dd/MM/yyyy à HH:mm').format(widget.appointmentTime);
    
    StringBuffer message = StringBuffer();
    message.writeln('📅 Informations du rendez-vous');
    message.writeln();
    message.writeln('Statut: $statusText');
    message.writeln();
    message.writeln('Date et heure: $timeText');
    message.writeln();
    message.writeln('Adresse de consultation:');
    message.writeln(_addressController.text.trim());
    
    // Ajouter l'icône d'itinéraire si c'est la position actuelle ou si l'adresse contient "Position actuelle"
    bool hasCurrentLocation = _currentLocation != null && 
        (_addressController.text.trim() == _currentLocation || 
         _addressController.text.contains('Position actuelle'));
    
    if (hasCurrentLocation) {
      message.writeln();
      message.writeln('🗺️ Itinéraire disponible');
    }
    
    message.writeln();
    
    if (_messageController.text.trim().isNotEmpty) {
      message.writeln('Message du médecin:');
      message.writeln(_messageController.text.trim());
      message.writeln();
    }
    
    message.writeln('---');
    message.writeln('Message envoyé automatiquement par votre médecin');
    
    return message.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.message, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(
            'Envoyer les informations',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations du rendez-vous:',
              style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.status == 'Confirmé' ? Icons.check_circle : Icons.schedule,
                        size: 16,
                        color: widget.status == 'Confirmé' ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.status,
                        style: TextStyle(
                          color: widget.status == 'Confirmé' ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yyyy à HH:mm').format(widget.appointmentTime),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Adresse de consultation:',
              style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: 'Saisissez l\'adresse de consultation...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                        icon: _isLoadingLocation 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                        label: Text(
                          _isLoadingLocation ? 'Récupération...' : 'Utiliser ma position actuelle',
                          style: GoogleFonts.roboto(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _addCurrentLocationToAddress,
                        icon: const Icon(Icons.add_location, size: 18),
                        label: Text(
                          'Ajouter ma position',
                          style: GoogleFonts.roboto(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Message supplémentaire (optionnel):',
              style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ajoutez un message pour le patient...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 3,
              minLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _sendMessage,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Envoyer'),
        ),
      ],
    );
  }
}
