import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hospital_virtuel/screens/doctor/chat.dart';
import 'package:hospital_virtuel/screens/patient/ordonnances_page.dart'; // Ajout de l'import pour OrdonnancesPage
import 'package:hospital_virtuel/screens/patient/rendezvous.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxdart/rxdart.dart'; // Ajout de l'import pour rxdart
import 'package:flutter/services.dart'; // Import pour SystemUiOverlayStyle
import 'package:hospital_virtuel/screens/settings/settings.dart'; // Importer la page des paramètres

class SoinsPage extends StatefulWidget {
  final VoidCallback? onNavigateToConsultations;
  final bool isDesktop;

  const SoinsPage({
    super.key,
    this.onNavigateToConsultations,
    this.isDesktop = false,
  });

  @override
  _SoinsPageState createState() => _SoinsPageState();
}

class _SoinsPageState extends State<SoinsPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _patientData;
  bool _isLoadingPatientData = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false; // Nouvelle variable d'état pour la visibilité de la barre de recherche
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _loadPatientData();
    }
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
        // Si le champ de recherche perd le focus et est vide, on le masque
        if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Fonction pour récupérer les conversations distinctes du patient avec les médecins
  Stream<List<Map<String, dynamic>>> _getChats() {
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Stream des messages envoyés par l'utilisateur
    Stream<QuerySnapshot> sentMessagesStream = FirebaseFirestore.instance
        .collection('messages')
        .where('senderId', isEqualTo: currentUser!.uid)
        .snapshots();

    // Stream des messages reçus par l'utilisateur
    Stream<QuerySnapshot> receivedMessagesStream = FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: currentUser!.uid)
        .snapshots();

    // Combinaison des deux streams
    return Rx.combineLatest2(
      sentMessagesStream,
      receivedMessagesStream,
      (QuerySnapshot sentSnapshot, QuerySnapshot receivedSnapshot) async {
        Map<String, Map<String, dynamic>> latestMessagesByContact = {};
        Map<String, String> searchableContentByContact = {};

        // Fonction pour traiter une liste de documents de messages
        void processMessages(List<QueryDocumentSnapshot> docs, bool isSentStream) {
          for (var doc in docs) {
            var message = doc.data() as Map<String, dynamic>;
            String contactId;
            if (isSentStream) {
              contactId = message['receiverId'] as String? ?? 'unknown_receiver';
            } else {
              contactId = message['senderId'] as String? ?? 'unknown_sender';
            }

            Timestamp? messageTimestamp = message['timestamp'] as Timestamp?;

            if (contactId.startsWith('unknown_')) continue; // Ignorer les messages avec contact inconnu

            if (messageTimestamp != null) {
              // Si ce contact n'est pas encore dans la map, ou si ce message est plus récent
              if (!latestMessagesByContact.containsKey(contactId) ||
                  (latestMessagesByContact[contactId]!['timestamp'] as Timestamp?)!
                      .compareTo(messageTimestamp) < 0) {
                latestMessagesByContact[contactId] = message;
              }
            }

            // Construire le contenu de recherche pour ce contact
            String messageText = message['message']?.toString() ?? '';
            String messageType = message['messageType']?.toString() ?? '';
            String fileName = message['fileName']?.toString() ?? '';
            
            if (!searchableContentByContact.containsKey(contactId)) {
              searchableContentByContact[contactId] = '';
            }
            searchableContentByContact[contactId] = (searchableContentByContact[contactId] ?? '') + '$messageText $messageType $fileName ';
          }
        }

        processMessages(sentSnapshot.docs, true);
        processMessages(receivedSnapshot.docs, false);

        // Récupérer les informations des médecins pour enrichir la recherche
        for (String contactId in latestMessagesByContact.keys) {
          try {
            DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
                .collection('doctors')
                .doc(contactId)
                .get();
            
            if (doctorDoc.exists) {
              var doctorData = doctorDoc.data() as Map<String, dynamic>?;
              String doctorName = doctorData?['name']?.toString() ?? '';
              String doctorSpecialty = doctorData?['specialty']?.toString() ?? '';
              
              // Ajouter les informations du médecin au contenu de recherche
              if (!searchableContentByContact.containsKey(contactId)) {
                searchableContentByContact[contactId] = '';
              }
              searchableContentByContact[contactId] = (searchableContentByContact[contactId] ?? '') + '$doctorName $doctorSpecialty ';
            }
          } catch (e) {
            print("Erreur lors de la récupération des données du médecin $contactId: $e");
          }
        }

        // Convertir la map en liste et enrichir avec le contenu de recherche
        List<Map<String, dynamic>> chats = [];
        for (String contactId in latestMessagesByContact.keys) {
          var chat = Map<String, dynamic>.from(latestMessagesByContact[contactId]!);
          chat['searchableContent'] = searchableContentByContact[contactId]?.toLowerCase() ?? '';
          chats.add(chat);
        }

        // Trier par le timestamp du dernier message
        chats.sort((a, b) {
          return (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp);
        });
        
        return chats;
      },
    ).asyncMap((chats) => chats);
  }

  // Récupérer l'état en ligne du médecin
  Future<String> _getOnlineStatus(String doctorId) async {
    try {
      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance.collection('doctors').doc(doctorId).get();
      if (doctorDoc.exists) {
        DateTime? lastOnline = doctorDoc['lastOnline'] != null
            ? (doctorDoc['lastOnline'] as Timestamp).toDate()
            : null;
        if (lastOnline == null) return 'Inconnue';

        final now = DateTime.now();
        final difference = now.difference(lastOnline);
        if (difference.inMinutes < 5) {
          return 'En ligne';
        } else {
          return 'En ligne il y a : ${_getTimeAgo(lastOnline)}';
        }
      }
      return 'Inconnue';
    } catch (e) {
      print("Erreur lors de la récupération de l'état en ligne : $e");
      return 'Inconnue';
    }
  }

  // Formater le temps écoulé
  String _getTimeAgo(DateTime lastOnline) {
    final now = DateTime.now();
    final difference = now.difference(lastOnline);

    if (difference.inDays > 0) {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''} ${difference.inHours % 24} heure${difference.inHours % 24 > 1 ? 's' : ''} ${difference.inMinutes % 60} minute${difference.inMinutes % 60 > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} heure${difference.inHours > 1 ? 's' : ''} ${difference.inMinutes % 60} minute${difference.inMinutes % 60 > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Il y a moins d\'une minute';
    }
  }

  // Formater la date pour l'affichage
  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return 'Aujourd\'hui ${DateFormat('HH:mm').format(date)}';
    } else if (messageDate == yesterday) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  Future<void> _loadPatientData() async {
    if (currentUser == null) {
      setState(() {
        _isLoadingPatientData = false;
      });
      return;
    }
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (userDoc.exists) {
        if (mounted) {
          setState(() {
            _patientData = userDoc.data() as Map<String, dynamic>;
          });
        }
      }
    } catch (e) {
      print("Erreur lors du chargement des données du patient: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur de chargement des données médicales.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPatientData = false;
        });
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _searchQuery = '';
        _searchFocusNode.unfocus();
      }
    });
  }

  String _formatMedicalKey(String key) {
    // Simple formatter for keys, can be expanded
    switch (key) {
      case 'nom': return 'Nom';
      case 'postnom': return 'Post-nom';
      case 'prenom': return 'Prénom';
      case 'dateNaissance': return 'Date de Naissance';
      case 'sexe': return 'Sexe';
      case 'groupeSanguin': return 'Groupe Sanguin';
      case 'allergies': return 'Allergies';
      case 'antecedentsMedicaux': return 'Antécédents Médicaux';
      case 'telephone': return 'Téléphone';
      case 'email': return 'Email';
      // Ajoutez d'autres traductions de clés si nécessaire
      default:
        return key.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (Match m) => ' ${m[0]}')
                  .capitalizeFirstLetter();
    }
  }

  Future<void> _downloadMedicalData() async {
    if (_patientData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune donnée à télécharger.')),
      );
      return;
    }

    String dataToShare = "Mes Données Médicales Personnelles:\n\n";
    _patientData!.forEach((key, value) {
      String formattedValue = value.toString();
      if (value is Timestamp) {
        formattedValue = DateFormat('dd/MM/yyyy').format(value.toDate());
      } else if (value is List) {
        formattedValue = value.join(', ');
      }
      dataToShare += "${_formatMedicalKey(key)}: $formattedValue\n";
    });

    await Share.share(dataToShare, subject: 'Mes Données Médicales - ${currentUser?.displayName ?? currentUser?.email ?? 'Patient'}');
  }

  void showMedicalDataDialog(BuildContext context) {
    if (currentUser == null && !_isLoadingPatientData && _patientData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur non connecté ou données non disponibles.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.medical_information_outlined, color: Colors.blue.shade700, size: 28),
              const SizedBox(width: 10),
              Text(
                'Mes Données Médicales',
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: _buildMedicalDataDialogContentWidget(),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Fermer', style: GoogleFonts.roboto(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        );
      },
    );
  }

  Widget _buildMedicalDataDialogContentWidget() {
    if (_isLoadingPatientData) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ));
    }
    if (_patientData == null) {
      return _buildNoMedicalDataAvailable();
    }
    return _buildPatientDataRows();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // En mode bureau, le fond est géré par la Card parente
      backgroundColor: widget.isDesktop
          ? Colors.transparent
          : Theme.of(context).colorScheme.surface.withOpacity(0.98),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getChats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Skeleton loader for better UX
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: 5, // Afficher 5 cartes de placeholder
                    itemBuilder: (context, index) => _buildLoadingCard(),
                  );
                }

                if (!snapshot.hasData || (snapshot.data!.isEmpty && _searchQuery.isEmpty)) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 100,
                            color: Colors.blue.shade300,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Aucune conversation',
                            style: GoogleFonts.lato(
                              fontSize: 22,
                              color: Colors.blueGrey.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Commencez une discussion avec vos médecins pour voir vos conversations ici.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 30),
                          if (widget.onNavigateToConsultations != null)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_comment_outlined),
                              label: const Text('Démarrer une consultation'),
                              onPressed: widget.onNavigateToConsultations,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                textStyle: GoogleFonts.lato(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                final allMessages = snapshot.data ?? [];
                final filteredMessages = allMessages.where((message) {
                  if (_searchQuery.isEmpty) {
                    return true;
                  }
                  final query = _searchQuery.toLowerCase();
                  final senderId = message['senderId'] as String? ?? '';
                  final receiverId = message['receiverId'] as String? ?? '';
                  final content = (message['message'] as String? ?? '').toLowerCase();
                  final searchableContent = message['searchableContent']?.toString() ?? '';

                  final contactId = (receiverId == currentUser?.uid ? senderId : receiverId).toLowerCase();
                  final doctorName = 'dr. $contactId';

                  // Recherche par mots-clés médicaux courants
                  List<String> medicalKeywords = [
                    'douleur', 'mal', 'fièvre', 'toux', 'maux de tête', 'nausée', 'vomissement',
                    'fatigue', 'stress', 'anxiété', 'dépression', 'insomnie', 'allergie',
                    'médicament', 'traitement', 'symptôme', 'diagnostic', 'consultation',
                    'rendez-vous', 'ordonnance', 'prescription', 'dosage', 'effet secondaire',
                    'tension', 'pression', 'diabète', 'hypertension', 'cholesterol',
                    'grossesse', 'accouchement', 'enfant', 'bébé', 'vaccin', 'vaccination',
                    'urgence', 'ambulance', 'hôpital', 'clinique', 'médecin', 'docteur',
                    'infirmier', 'infirmière', 'pharmacie', 'pharmacien', 'analyse',
                    'radiographie', 'scanner', 'irm', 'échographie', 'biopsie'
                  ];
                  
                  // Vérifier si la requête correspond à un mot-clé médical
                  bool isMedicalKeyword = medicalKeywords.any((keyword) => 
                    keyword.toLowerCase().contains(query) || 
                    query.contains(keyword.toLowerCase())
                  );
                  
                  // Recherche principale
                  bool basicSearch = doctorName.contains(query) || content.contains(query);
                  
                  // Recherche approfondie dans le contenu de la conversation
                  bool deepSearch = searchableContent.contains(query);
                  
                  // Recherche par mots-clés médicaux
                  bool medicalSearch = isMedicalKeyword && searchableContent.isNotEmpty;
                  
                  return basicSearch || deepSearch || medicalSearch;
                }).toList();

                if (filteredMessages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 100,
                            color: Colors.blue.shade300,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Aucun résultat trouvé',
                            style: GoogleFonts.lato(
                              fontSize: 22, 
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Colors.blueGrey.shade800, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Essayez de rechercher avec d\'autres mots-clés.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              fontSize: 16, 
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white70 
                                  : Colors.grey.shade600
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true, // Important pour ListView dans SingleChildScrollView
                  physics: const NeverScrollableScrollPhysics(), // Désactive son propre défilement
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredMessages.length,
                  itemBuilder: (context, index) {
                    final message = filteredMessages[index];

                    final senderId = message['senderId'] ?? 'Inconnu';
                    final receiverId = message['receiverId'] ?? 'Inconnu';
                    final content = message['message'] ?? '';
                    final timestamp = message['timestamp'] != null ? message['timestamp'] as Timestamp : null;

                    final contactId = receiverId == FirebaseAuth.instance.currentUser?.uid
                        ? senderId
                        : receiverId;
                    
                    // Déterminer si le message est non lu du point de vue du patient
                    final bool isUnread = message['senderId'] == contactId && (message['isRead'] == false);

                    return FutureBuilder<String>(
                      future: _getOnlineStatus(contactId),
                      builder: (context, onlineSnapshot) {
                        if (onlineSnapshot.connectionState == ConnectionState.waiting) {
                          return _buildLoadingCard();
                        }

                        final onlineStatus = onlineSnapshot.data ?? 'Inconnue';
                        final isOnline = onlineStatus == 'En ligne';

                        return Card(
                          elevation: 2.5,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          shadowColor: Colors.blue.withOpacity(0.12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    contactId: contactId,
                                    contactName: "Dr. $contactId",
                                  ),
                                ),
                              );
                            },
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Icon(Icons.medical_services_outlined, size: 30, color: Colors.blue.shade800),
                                ),
                                Positioned(
                                  right: 1,
                                  bottom: 1,
                                  child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: BoxDecoration(
                                      color: isOnline ? Colors.green.shade500 : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              'Dr. $contactId',
                              style: GoogleFonts.lato(
                                fontSize: 17, 
                                fontWeight: FontWeight.bold, 
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white 
                                    : Colors.black87
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    content,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.roboto(
                                      fontSize: 14.5,
                                      color: isUnread 
                                          ? Colors.blue.shade900 
                                          : (Theme.of(context).brightness == Brightness.dark 
                                              ? Colors.white70 
                                              : Colors.grey.shade700),
                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    onlineStatus,
                                    style: GoogleFonts.roboto(
                                      fontSize: 13,
                                      color: isOnline 
                                          ? Colors.green.shade700 
                                          : (Theme.of(context).brightness == Brightness.dark 
                                              ? Colors.white60 
                                              : Colors.grey.shade600),
                                      fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (timestamp != null)
                                  Text(
                                    _formatDate(timestamp),
                                    style: GoogleFonts.roboto(
                                      fontSize: 12, 
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.white60 
                                          : Colors.blueGrey.shade400
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                if (isUnread)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else
                                  const SizedBox(width: 10, height: 10), // Placeholder for alignment
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      // On n'affiche l'AppBar que sur mobile
      appBar: widget.isDesktop
          ? null
          : AppBar(
              elevation: 3.0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              iconTheme: const IconThemeData(color: Colors.white),
              centerTitle: false, // Aligner le titre à gauche
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.lightBlue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _isSearching
                    ? TextField(
                        key: const ValueKey('searchField'),
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Rechercher par médecin, symptôme, médicament...',
                          hintStyle: GoogleFonts.roboto(color: Colors.white70),
                          border: InputBorder.none,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                        ),
                        style: GoogleFonts.roboto(color: Colors.white, fontSize: 17),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      )
                    : Text(
                        key: const ValueKey('titleText'),
                        'Soins',
                        style: GoogleFonts.lato(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
              ),
              actions: [
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
                  tooltip: _isSearching ? 'Fermer la recherche' : 'Rechercher',
                  onPressed: () {
                    _toggleSearch();
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  tooltip: 'Plus d\'options',
                  onSelected: (value) {
                    if (value == 'ordonnances') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdonnancesPage()));
                    } else if (value == 'rendezvous') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => RendezvousPage()));
                    } else if (value == 'settings') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'ordonnances',
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text('Mes Ordonnances', style: GoogleFonts.roboto()),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'rendezvous',
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text('Mes Rendez-vous', style: GoogleFonts.roboto()),
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'settings',
                      child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Paramètres')),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 2.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade200),
        title: Container(
          height: 18,
          width: 150,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 15,
                width: 220,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Container(
                height: 13,
                width: 100,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoMedicalDataAvailable() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Text(
            'Données médicales non disponibles pour le moment.',
          style: GoogleFonts.roboto(color: Colors.grey.shade700, fontStyle: FontStyle.italic, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget buildDataRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: GoogleFonts.roboto(fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800, fontSize: 15)),
          Expanded(child: Text(value != null && value.isNotEmpty ? value : 'Non spécifié', style: GoogleFonts.roboto(color: Colors.blueGrey.shade600, fontSize: 15))),
        ],
      ),
    );
  }

  String formatDateFromData(dynamic timestampData) {
    if (timestampData is Timestamp) return DateFormat('dd/MM/yyyy').format(timestampData.toDate());
    if (timestampData is String) return timestampData;
    return 'Non spécifiée';
  }

  Widget _buildPatientDataRows() {
    // Le titre et l'icône sont maintenant dans AlertDialog.title
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        buildDataRow('Nom Complet', '${_patientData!['prenom'] ?? ''} ${_patientData!['nom'] ?? ''} ${_patientData!['postnom'] ?? ''}'.trim()),
        buildDataRow('Date de Naissance', formatDateFromData(_patientData!['dateNaissance'])),
        buildDataRow('Sexe', _patientData!['sexe'] as String?),
        buildDataRow('Téléphone', _patientData!['telephone'] as String?),
        buildDataRow('Email', _patientData!['email'] as String?),
        buildDataRow('Groupe Sanguin', _patientData!['groupeSanguin'] as String?),
        buildDataRow('Allergies', (_patientData!['allergies'] as List<dynamic>?)?.join(', ') ?? _patientData!['allergies'] as String?),
        buildDataRow('Antécédents Médicaux', (_patientData!['antecedentsMedicaux'] as List<dynamic>?)?.join(', ') ?? _patientData!['antecedentsMedicaux'] as String?),
        const SizedBox(height: 20),
        Center(child: ElevatedButton.icon(
          icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white, size: 20),
          label: Text('Obtenir une copie', style: GoogleFonts.roboto(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
          onPressed: _downloadMedicalData,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalizeFirstLetter() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
