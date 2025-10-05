import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_virtuel/screens/settings/settings.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import for date formatting locales

class HistoriquePage extends StatefulWidget {
  final bool isDesktop;
  
  const HistoriquePage({super.key, this.isDesktop = false});

  @override
  _HistoriquePageState createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage> {
  String _filter = "Tous";
  final String? _doctorId = FirebaseAuth.instance.currentUser?.uid;
  int _totalConsultations = 0;
  int _consultationsCetteSemaine = 0;
  int _consultationsCeMois = 0;
  int _consultationsCetteAnnee = 0;
  int _totalConfirmedRendezVous = 0;
  int _confirmedRendezVousCetteSemaine = 0;
  int _confirmedRendezVousCeMois = 0;
  int _confirmedRendezVousCetteAnnee = 0;
  bool _isLoading = true;
  List<DocumentSnapshot> _allMessages = [];
  List<DocumentSnapshot> _filteredMessages = [];
  List<DocumentSnapshot> _allRendezVous = [];

  // Fonction pour obtenir les messages lus (consultations)
  Future<void> _loadMessages() async {
    if (_doctorId == null) {
      debugPrint("Erreur : Aucun médecin connecté.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer tous les messages lus pour ce médecin
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: _doctorId)
          .where('isRead', isEqualTo: true)
          .get();

      _allMessages = messagesSnapshot.docs;
      
      // Récupérer tous les rendez-vous pour ce médecin
      final rendezVousSnapshot = await FirebaseFirestore.instance
          .collection('rendezvous')
          .where('doctorId', isEqualTo: _doctorId)
          .get();
          
      _allRendezVous = rendezVousSnapshot.docs;
      
      _applyFilter();
    } catch (e) {
      debugPrint("Erreur lors du chargement des données: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fonction pour appliquer le filtre de période
  void _applyFilter() {
    if (_allMessages.isEmpty) {
      _filteredMessages = [];
      return;
    }

    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    DateTime startOfYear = DateTime(now.year, 1, 1);

    // Filtrer les messages en fonction de la période sélectionnée
    _filteredMessages = _allMessages.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp).toDate();

      switch (_filter) {
        case "Cette semaine":
          return timestamp.isAfter(startOfWeek);
        case "Ce mois":
          return timestamp.isAfter(startOfMonth);
        case "Cette année":
          return timestamp.isAfter(startOfYear);
        case "Tous":
          return true;
        default:
          return true;
      }
    }).toList();

    // Trier les messages par date (du plus récent au plus ancien)
    _filteredMessages.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTimestamp = aData['timestamp'] as Timestamp;
      final bTimestamp = bData['timestamp'] as Timestamp;
      return bTimestamp.compareTo(aTimestamp);
    });

    // Mettre à jour les statistiques
    _updateStatistics();
  }

  // Fonction pour mettre à jour les statistiques
  void _updateStatistics() {
    // Regrouper les messages par patient
    Map<String, List<DateTime>> patientConsultations = {};
    
    for (var doc in _allMessages) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String;
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      
      if (!patientConsultations.containsKey(senderId)) {
        patientConsultations[senderId] = [];
      }
      
      // Vérifier si c'est une nouvelle consultation (écart de 2 jours ou plus)
      bool isNewConsultation = true;
      for (var date in patientConsultations[senderId]!) {
        if ((timestamp.difference(date).inDays.abs() < 2)) {
          isNewConsultation = false;
          break;
        }
      }
      
      if (isNewConsultation) {
        patientConsultations[senderId]!.add(timestamp);
      }
    }

    // Compter les consultations totales
    _totalConsultations = 0;
    for (var consultations in patientConsultations.values) {
      _totalConsultations += consultations.length;
    }

    // Compter les consultations par période
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    DateTime startOfYear = DateTime(now.year, 1, 1);

    _consultationsCetteSemaine = 0;
    _consultationsCeMois = 0;
    _consultationsCetteAnnee = 0;

    for (var consultations in patientConsultations.values) {
      for (var date in consultations) {
        if (date.isAfter(startOfWeek)) {
          _consultationsCetteSemaine++;
        }
        if (date.isAfter(startOfMonth)) {
          _consultationsCeMois++;
        }
        if (date.isAfter(startOfYear)) {
          _consultationsCetteAnnee++;
        }
      }
    }

    // Compter les rendez-vous confirmés par période
    _totalConfirmedRendezVous = 0;
    _confirmedRendezVousCetteSemaine = 0;
    _confirmedRendezVousCeMois = 0;
    _confirmedRendezVousCetteAnnee = 0;

    List<DocumentSnapshot> confirmedRendezVous = _allRendezVous.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['status'] ?? 'Non confirmé') == 'Confirmé';
    }).toList();

    _totalConfirmedRendezVous = confirmedRendezVous.length;

    for (var doc in confirmedRendezVous) {
      final data = doc.data() as Map<String, dynamic>;
      final appointmentTime = (data['appointmentTime'] as Timestamp).toDate();
      
      if (appointmentTime.isAfter(startOfWeek)) {
        _confirmedRendezVousCetteSemaine++;
      }
      if (appointmentTime.isAfter(startOfMonth)) {
        _confirmedRendezVousCeMois++;
      }
      if (appointmentTime.isAfter(startOfYear)) {
        _confirmedRendezVousCetteAnnee++;
      }
    }
  }

  int _getConsultationsCount() {
    switch (_filter) {
      case "Cette semaine":
        return _consultationsCetteSemaine;
      case "Ce mois":
        return _consultationsCeMois;
      case "Cette année":
        return _consultationsCetteAnnee;
      case "Tous":
        return _totalConsultations;
      default:
        return _totalConsultations;
    }
  }

  int _getRendezVousCount() {
    switch (_filter) {
      case "Cette semaine":
        return _confirmedRendezVousCetteSemaine;
      case "Ce mois":
        return _confirmedRendezVousCeMois;
      case "Cette année":
        return _confirmedRendezVousCetteAnnee;
      case "Tous":
        return _totalConfirmedRendezVous;
      default:
        return _totalConfirmedRendezVous;
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize French locale for date formatting
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_doctorId == null) {
      return Scaffold(
        appBar: widget.isDesktop
            ? null // Pas d'AppBar en mode desktop
            : AppBar(
                systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                ),
                title: Text('Historique', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
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
              Text('Veuillez vous reconnecter pour voir l\'historique.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
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
                'Historique',
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
                  onSelected: (String value) {
                    if (value == 'settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    } else {
                      setState(() {
                        _filter = value;
                      });
                      _applyFilter();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text('Filtrer par période', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor)),
                    ),
                    ...["Tous", "Cette semaine", "Ce mois", "Cette année"].map((String value) {
                      return CheckedPopupMenuItem<String>(value: value, checked: _filter == value, child: Text(value));
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
      body: RefreshIndicator(
        onRefresh: _loadMessages,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildStatsSection()),
            _isLoading
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                : _buildConsultationsSliverList(),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationsSliverList() {
    // Regrouper les messages par patient
    // (Cette logique est déjà présente et correcte pour _filteredMessages)
    Map<String, List<DocumentSnapshot>> patientMessages = {};
    
    for (var doc in _filteredMessages) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String;
      
      if (!patientMessages.containsKey(senderId)) {
        patientMessages[senderId] = [];
      }
      
      patientMessages[senderId]!.add(doc);
    }

    // Trier les messages par date pour chaque patient
    for (var patientId in patientMessages.keys) {
      patientMessages[patientId]!.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aTimestamp = aData['timestamp'] as Timestamp;
        final bTimestamp = bData['timestamp'] as Timestamp;
        return bTimestamp.compareTo(aTimestamp);
      });
    }

    if (patientMessages.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('Aucune consultation trouvée pour cette période.')),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
        final patientId = patientMessages.keys.elementAt(index);
        final patientDocs = patientMessages[patientId]!;
        
        // Utiliser le message le plus récent pour afficher les informations
        final latestMessage = patientDocs.first;
        final data = latestMessage.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp).toDate(); // This is the latest message timestamp
        final dateFormatted = DateFormat("dd/MM/yyyy HH:mm").format(timestamp);
        
        // Calculer le nombre de consultations (messages espacés de 2 jours ou plus)
        int consultationCount = 0;
        DateTime? lastConsultationDate;
        List<DateTime> consultationDates = [];
        
        for (var doc in patientDocs) {
          final msgData = doc.data() as Map<String, dynamic>;
          final msgTimestamp = (msgData['timestamp'] as Timestamp).toDate();
          
          if (lastConsultationDate == null || 
              msgTimestamp.difference(lastConsultationDate).inDays.abs() >= 2) {
            consultationCount++;
            lastConsultationDate = msgTimestamp;
            consultationDates.add(msgTimestamp);
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          child: ExpansionTile(
            title: Text('ID: $patientId'),
            subtitle: Text('Dernière consultation: $dateFormatted\nNombre de consultations: $consultationCount'),
            leading: const Icon(Icons.person, color: Colors.blue),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dates des consultations:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...consultationDates.map((date) {
                      final dateFormatted = DateFormat("dd/MM/yyyy HH:mm").format(date);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              dateFormatted,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
        childCount: patientMessages.length,
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistiques (${_filter.toLowerCase()})',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColorDark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _buildStatCard(
                    'Consultations', _getConsultationsCount(), Icons.medical_services_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                    'Rendez-vous Confirmés', _getRendezVousCount(), Icons.event_available_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
