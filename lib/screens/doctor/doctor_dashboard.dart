import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hospital_virtuel/screens/doctor/forum.dart'; // Assurez-vous que ce fichier existe
import 'package:hospital_virtuel/screens/doctor/consultation.dart';
import 'package:hospital_virtuel/screens/doctor/historique.dart';
import 'package:hospital_virtuel/screens/doctor/rendezvous.dart';
import 'package:hospital_virtuel/screens/settings/settings.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // Importation de Google Fonts
import 'package:hospital_virtuel/screens/doctor/chat.dart' as chat_ai;

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _currentIndex = 0;
  double? _fabLeft;
  double? _fabTop;
  bool _isDragging = false;
  ValueNotifier<Offset>? _fabOffset;
  final ValueNotifier<bool> _isFabDragging = ValueNotifier(false);
  int? _lockedEdge; // 0=left,1=right,2=top,3=bottom

  // State from ConsultationPage
  List<Map<String, dynamic>> contacts = [];
  List<Map<String, dynamic>> filteredContacts = [];
  String errorMessage = '';
  bool showUnreadOnly = false;
  bool isLoading = true;
  String searchQuery = '';
  bool isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      _filterContacts();
    });
  }

  void _startSearch() {
    setState(() {
      isSearchMode = true;
      _searchController.clear();
      searchQuery = '';
      _filterContacts();
    });
  }

  void _endSearch() {
    setState(() {
      isSearchMode = false;
      _searchController.clear();
      searchQuery = '';
      _filterContacts();
    });
  }

  void _filterContacts() {
    if (searchQuery.isEmpty) {
      filteredContacts = List.from(contacts);
    } else {
      filteredContacts = contacts.where((contact) {
        // Rechercher dans l'ID du contact
        String contactId = contact['id']?.toString().toLowerCase() ?? '';
        
        // Rechercher dans le prénom
        String firstName = contact['firstName']?.toString().toLowerCase() ?? '';
        
        // Rechercher dans le nom
        String lastName = contact['lastName']?.toString().toLowerCase() ?? '';
        
        // Rechercher dans le nom complet
        String name = contact['name']?.toString().toLowerCase() ?? '';
        
        // Rechercher dans l'email
        String email = contact['email']?.toString().toLowerCase() ?? '';
        
        // Rechercher dans le dernier message
        String lastMessage = contact['lastMessage']?.toString().toLowerCase() ?? '';
        
        // Rechercher dans le statut (en ligne, vu il y a...)
        String status = contact['isOnline'] == true ? 'en ligne' : 'hors ligne';
        
        // Rechercher dans le type (consultation, feeling)
        String type = contact['isConsultation'] == true ? 'consultation' : 
                     contact['isFeeling'] == true ? 'feeling' : '';
        
        // RECHERCHE APPROFONDIE : Rechercher dans tout le contenu de la conversation
        String searchableContent = contact['searchableContent']?.toString() ?? '';
        
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
          keyword.toLowerCase().contains(searchQuery) || 
          searchQuery.contains(keyword.toLowerCase())
        );
        
        // Recherche principale
        bool basicSearch = contactId.contains(searchQuery) || 
               firstName.contains(searchQuery) ||
               lastName.contains(searchQuery) ||
               name.contains(searchQuery) ||
               email.contains(searchQuery) ||
               lastMessage.contains(searchQuery) ||
               status.contains(searchQuery) ||
               type.contains(searchQuery);
        
        // Recherche approfondie dans le contenu de la conversation
        bool deepSearch = searchableContent.contains(searchQuery);
        
        // Recherche par mots-clés médicaux
        bool medicalSearch = isMedicalKeyword && searchableContent.isNotEmpty;
        
        return basicSearch || deepSearch || medicalSearch;
      }).toList();
    }
  }

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
        return null; // Utilise toute la largeur
      case 'tablet':
        return screenWidth * 0.9;
      case 'small_desktop':
        return screenWidth * 0.8;
      case 'large_desktop':
        return 1200; // Largeur fixe pour les grands écrans
      default:
        return null;
    }
  }

  Future<void> _loadContacts() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Utilisateur non authentifié";
        isLoading = false;
      });
      return;
    }

    try {
      var messagesQuery = await FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: user.uid)
          .get();

      var sentMessagesQuery = await FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: user.uid)
          .get();

      var allMessages = [...messagesQuery.docs, ...sentMessagesQuery.docs];

      allMessages.sort((a, b) {
        var aData = a.data() as Map<String, dynamic>?;
        var bData = b.data() as Map<String, dynamic>?;
        Timestamp? aTime = aData?['timestamp'] as Timestamp?;
        Timestamp? bTime = bData?['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      Set<String> contactIds = {};
      for (var doc in allMessages) {
        var data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          String? receiverId = data['receiverId']?.toString();
          String? senderId = data['senderId']?.toString();
          
          String? contactId;
          if (receiverId == user.uid) {
            contactId = senderId;
          } else {
            contactId = receiverId;
          }
          
          if (contactId != null) {
            contactIds.add(contactId);
          }
        }
      }

      // Ajouter les consultations à domicile assignées à ce médecin
      var consultationsQuery = await FirebaseFirestore.instance
          .collection('home_consultations')
          .where('assignedDoctorId', isEqualTo: user.uid)
          .get();

      for (var doc in consultationsQuery.docs) {
        String patientId = doc['userId'];
        if (!contactIds.contains(patientId)) {
          contactIds.add(patientId);
        }
      }

      var feelingsQuery = await FirebaseFirestore.instance
          .collection('feelings')
          .where('doctorId', isEqualTo: user.uid)
          .get();

      for (var doc in feelingsQuery.docs) {
        String patientId = doc['patientId'];
        if (!contactIds.contains(patientId)) {
          contactIds.add(patientId);
        }
      }

      List<Map<String, dynamic>> tempContacts = [];
      for (String id in contactIds) {
        var unreadCount = allMessages
            .where((doc) {
              var data = doc.data() as Map<String, dynamic>?;
              return data?['senderId'] == id && data?['receiverId'] == user.uid && data?['isRead'] == false;
            })
            .length;

        var lastMessage = allMessages
            .where((doc) {
              var data = doc.data() as Map<String, dynamic>?;
              return (data?['senderId'] == id && data?['receiverId'] == user.uid) || (data?['senderId'] == user.uid && data?['receiverId'] == id);
            })
            .firstOrNull;

        // Récupérer tous les messages de cette conversation pour la recherche approfondie
        var conversationMessages = allMessages
            .where((doc) {
              var data = doc.data() as Map<String, dynamic>?;
              return (data?['senderId'] == id && data?['receiverId'] == user.uid) || (data?['senderId'] == user.uid && data?['receiverId'] == id);
            })
            .toList();

        // Créer un texte de recherche combiné avec tous les messages
        String searchableContent = '';
        for (var msg in conversationMessages) {
          var msgData = msg.data() as Map<String, dynamic>?;
          String messageText = msgData?['message']?.toString() ?? '';
          String messageType = msgData?['messageType']?.toString() ?? '';
          String fileName = msgData?['fileName']?.toString() ?? '';
          
          searchableContent += '$messageText $messageType $fileName ';
        }

        var userDoc = await FirebaseFirestore.instance.collection('users').doc(id).get();

        if (userDoc.exists) {
          // Vérifier si c'est une consultation à domicile
          bool isConsultation = consultationsQuery.docs.any((doc) => doc['userId'] == id);
          var userData = userDoc.data() as Map<String, dynamic>?;
          
          tempContacts.add({
            "id": id,
            "unreadCount": unreadCount,
            "lastMessage": (lastMessage?.data() as Map<String, dynamic>?)?['message'] ?? (isConsultation ? "Nouvelle consultation" : "Nouveau Feeling"),
            "lastMessageTime": (lastMessage?.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp?,
            "isOnline": userData?['isOnline'] ?? false,
            "lastSeen": userData?['lastSeen'] as Timestamp?,
            "isFeeling": feelingsQuery.docs.any((doc) => doc['patientId'] == id),
            "isConsultation": isConsultation,
            // Ajouter les informations du patient pour la recherche
            "firstName": userData?['first_name'] ?? userData?['prenom'] ?? '',
            "lastName": userData?['last_name'] ?? userData?['nom'] ?? '',
            "name": userData?['name'] ?? '',
            "email": userData?['email'] ?? '',
            // Contenu de recherche approfondie
            "searchableContent": searchableContent.toLowerCase(),
            "conversationMessages": conversationMessages.length,
          });
        }
      }

      tempContacts.sort((a, b) {
        if (a['unreadCount'] > 0 && b['unreadCount'] == 0) return -1;
        if (a['unreadCount'] == 0 && b['unreadCount'] > 0) return 1;
        Timestamp? aTime = a['lastMessageTime'];
        Timestamp? bTime = b['lastMessageTime'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;
      setState(() {
        contacts = tempContacts;
        _filterContacts(); // Initialiser filteredContacts
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Erreur : $e';
        isLoading = false;
      });
    }
  }

  Future<void> _markMessagesAsRead(String contactId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      var querySnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: user.uid)
          .where('senderId', isEqualTo: contactId)
          .where('isRead', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in querySnapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
        if (!mounted) return;
        setState(() {
          for (var contact in contacts) {
            if (contact['id'] == contactId) {
              contact['unreadCount'] = 0;
            }
          }
          _filterContacts(); // Mettre à jour filteredContacts
        });
      }
    } catch (e) {
      print("Erreur lors du marquage des messages comme lus: $e");
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);
    if (difference.inDays > 0) {
      return DateFormat('dd/MM').format(messageTime);
    } else {
      return DateFormat('HH:mm').format(messageTime);
    }
  }

  String _formatLastSeen(Timestamp? lastSeen) {
    if (lastSeen == null) return '';
    final now = DateTime.now();
    final seenTime = lastSeen.toDate();
    final difference = now.difference(seenTime);
    if (difference.inMinutes < 1) {
      return 'En ligne';
    } else if (difference.inMinutes < 60) {
      return 'Vu il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Vu il y a ${difference.inHours} h';
    } else {
      return 'Vu le ${DateFormat('dd/MM').format(seenTime)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showConsultationAppBar = _currentIndex == 0;
    final String deviceType = _getDeviceType(context);
    final bool isMobile = deviceType == 'mobile';
    final bool isTablet = deviceType == 'tablet';
    final bool isDesktop = deviceType == 'small_desktop' || deviceType == 'large_desktop';
    final ThemeData theme = Theme.of(context);

    final List<Widget> _pages = [
      ConsultationPage(
        isLoading: isLoading,
        errorMessage: errorMessage,
        contacts: filteredContacts,
        showUnreadOnly: showUnreadOnly,
        onRefresh: _loadContacts,
        onTapContact: _markMessagesAsRead,
        formatTime: _formatTime,
        formatLastSeen: _formatLastSeen,
      ),
      ForumPage(isDesktop: isDesktop),
      RendezvousPage(isDesktop: isDesktop),
      HistoriquePage(isDesktop: isDesktop),
    ];

    // Layout pour desktop avec navigation latérale
    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Menu latéral
            Container(
              width: 120,
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Logo/icône d'application
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade700,
                    child: const Icon(Icons.medical_services, color: Colors.white),
                  ),
                  const SizedBox(height: 30),
                  // Boutons du menu latéral
                  _buildDesktopNavButton(Icons.medical_services, 0, 'Consultation'),
                  _buildDesktopNavButton(Icons.forum, 1, 'Forum'),
                  _buildDesktopNavButton(Icons.calendar_today, 2, 'Rendez-vous'),
                  _buildDesktopNavButton(Icons.history, 3, 'Historique'),
                  const Spacer(),
                  // Bouton Paramètres
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    },
                    icon: const Icon(Icons.settings, color: Colors.white70),
                    tooltip: 'Paramètres',
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Contenu principal
            Expanded(
              child: Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  toolbarHeight: 80, // Augmentation de la hauteur de l'AppBar
                  title: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/img2.JPG',
                          width: 50, // Image plus grande
                          height: 50, // Image plus grande
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16), // Plus d'espace
                      Text(
                        'Afya Bora',
                        style: GoogleFonts.lato(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22, // Texte plus grand
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _getAppBarTitle(),
                        style: GoogleFonts.lato(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24, // Titre plus grand
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 66), // Ajusté pour équilibrer
                    ],
                  ),
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade800, Colors.lightBlue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  actions: [
                    // Actions pour desktop - seulement dans l'onglet Consultation
                    if (_currentIndex == 0) ...[
                      IconButton(
                        icon: Icon(
                          showUnreadOnly ? Icons.all_inbox_outlined : Icons.mark_chat_unread_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () => setState(() => showUnreadOnly = !showUnreadOnly),
                        tooltip: showUnreadOnly ? 'Voir tous les messages' : 'Voir messages non lus',
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadContacts,
                        tooltip: 'Actualiser',
                      ),
                    ],
                    // Actions pour les autres onglets
                    if (_currentIndex == 1) ...[
                      // Actions pour Forum
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () => _handleForumActions('add_post'),
                        tooltip: 'Nouveau post',
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () => _handleForumActions('search'),
                        tooltip: 'Rechercher',
                      ),
                    ],
                    if (_currentIndex == 2) ...[
                      // Actions pour Rendez-vous
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () => _handleRendezvousActions('add_rendezvous'),
                        tooltip: 'Nouveau rendez-vous',
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_view_month, color: Colors.white),
                        onPressed: () => _handleRendezvousActions('calendar_view'),
                        tooltip: 'Vue calendrier',
                      ),
                    ],
                    if (_currentIndex == 3) ...[
                      // Actions pour Historique
                      IconButton(
                        icon: const Icon(Icons.filter_list, color: Colors.white),
                        onPressed: () => _handleHistoriqueActions('filter'),
                        tooltip: 'Filtrer',
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: () => _handleHistoriqueActions('download'),
                        tooltip: 'Télécharger',
                      ),
                    ],
                  ],
                ),
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    final content = Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _getMaxContentWidth(context) ?? 1000,
                          ),
                          child: Card(
                            elevation: 4.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: IndexedStack(
                              index: _currentIndex,
                              children: _pages,
                            ),
                          ),
                        ),
                      ),
                    );

                    return Stack(
                      children: [
                        content,
                        _buildDraggableFab(context, constraints),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Layout pour mobile/tablet avec navigation en bas
    return Scaffold(
      appBar: showConsultationAppBar
          ? AppBar(
              systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
              title: isSearchMode
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: _getResponsiveFontSize(context, baseSize: 16),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom, symptôme, médicament...',
                        hintStyle: GoogleFonts.roboto(
                          color: Colors.white70,
                          fontSize: _getResponsiveFontSize(context, baseSize: 16),
                        ),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.white,
                          size: _getResponsiveFontSize(context, baseSize: 20),
                        ),
                      ),
                    )
                  : Text(
                      'Afya Bora',
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: _getResponsiveFontSize(context, baseSize: 20),
                      ),
                    ),
              centerTitle: !isMobile && !isSearchMode, // Centrer le titre sur tablette et desktop
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
                // Actions pour le mode de recherche
                if (isSearchMode) ...[
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: _endSearch,
                    tooltip: 'Annuler la recherche',
                  ),
                ] else ...[
                  // Afficher les actions différemment selon la taille d'écran
                  if (isMobile)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'toggle_unread') {
                        setState(() => showUnreadOnly = !showUnreadOnly);
                      } else if (value == 'refresh') {
                        _loadContacts();
                      } else if (value == 'search') {
                        _startSearch();
                      } else if (value == 'settings') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsPage()),
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'toggle_unread',
                        child: ListTile(
                          leading: Icon(showUnreadOnly
                              ? Icons.all_inbox_outlined
                              : Icons.mark_chat_unread_outlined),
                          title: Text(showUnreadOnly
                              ? 'Voir tous les messages'
                              : 'Voir messages non lus'),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'search',
                        child: ListTile(
                          leading: Icon(Icons.search),
                          title: Text('Rechercher'),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'refresh',
                        child: ListTile(
                          leading: Icon(Icons.refresh),
                          title: Text('Actualiser'),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'settings',
                        child: ListTile(
                          leading: Icon(Icons.settings),
                          title: Text('Paramètres'),
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    tooltip: 'Plus d\'options',
                    )
                else
                  // Actions pour tablette
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          showUnreadOnly ? Icons.all_inbox_outlined : Icons.mark_chat_unread_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () => setState(() => showUnreadOnly = !showUnreadOnly),
                        tooltip: showUnreadOnly ? 'Voir tous les messages' : 'Voir messages non lus',
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: _startSearch,
                        tooltip: 'Rechercher',
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadContacts,
                        tooltip: 'Actualiser',
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SettingsPage()),
                          );
                        },
                        tooltip: 'Paramètres',
                      ),
                    ],
                ),
                ],
              ],
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _getMaxContentWidth(context) ?? double.infinity,
              ),
              child: IndexedStack(
                index: _currentIndex,
                children: _pages,
              ),
            ),
          );
          return Stack(
            children: [
              content,
              _buildDraggableFab(context, constraints),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.blueGrey.shade400,
        selectedLabelStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.w600, 
          fontSize: _getResponsiveFontSize(context, baseSize: 11)
        ),
        unselectedLabelStyle: GoogleFonts.roboto(
          fontSize: _getResponsiveFontSize(context, baseSize: 10)
        ),
        elevation: 10.0,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services, size: isTablet ? 28 : 24),
            label: 'Consultation',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum, size: isTablet ? 28 : 24),
            label: 'Forum',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today, size: isTablet ? 28 : 24),
            label: 'Rendez-vous',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history, size: isTablet ? 28 : 24),
            label: 'Historique',
          ),
        ],
      ),
    );
  }

  // Méthode pour construire les boutons de navigation desktop
  Widget _buildDesktopNavButton(IconData icon, int index, String tooltip) {
    return Column(
      children: [
        IconButton(
          icon: Icon(
            icon,
            color: _currentIndex == index ? Colors.white : Colors.white70,
            size: 30
          ),
          onPressed: () => setState(() => _currentIndex = index),
          tooltip: tooltip,
        ),
        Text(
          tooltip,
          style: GoogleFonts.roboto(
            fontSize: 10,
            color: _currentIndex == index ? Colors.white : Colors.white70
          )
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // Méthode pour obtenir le titre de l'AppBar
  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0: return 'Consultation';
      case 1: return 'Forum';
      case 2: return 'Rendez-vous';
      case 3: return 'Historique';
      default: return 'Afya Bora';
    }
  }

  Widget _buildMyAfyaAiFab(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => chat_ai.ChatPage(
              contactId: 'ai_bot',
              contactName: 'MyAFYA AI',
            ),
          ),
        );
      },
      child: const Icon(Icons.smart_toy, color: Colors.white),
      backgroundColor: Colors.blue.shade700,
    );
  }

  Widget _buildDraggableFab(BuildContext context, BoxConstraints constraints) {
    const double fabSize = 56;
    const double margin = 8;
    final mediaQuery = MediaQuery.of(context);
    final double statusBar = mediaQuery.padding.top;
    final bool isDesktop = _getDeviceType(context).contains('desktop');
    final double topSafeMargin = (isDesktop ? 96.0 : kToolbarHeight) + statusBar;
    final double maxLeft = constraints.maxWidth - fabSize - margin;
    final double maxTop = constraints.maxHeight - fabSize - margin;

    final double initialLeft = _fabLeft ?? maxLeft; // défaut: bas droite
    final double initialTop = _fabTop ?? maxTop;

    return AnimatedPositioned(
      left: _fabLeft ?? initialLeft,
      top: _fabTop ?? initialTop,
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _fabLeft = (_fabLeft ?? initialLeft) + details.delta.dx;
            _fabTop = (_fabTop ?? initialTop) + details.delta.dy;
            if (_fabLeft! < margin) _fabLeft = margin;
            if (_fabTop! < topSafeMargin) _fabTop = topSafeMargin;
            if (_fabLeft! > maxLeft) _fabLeft = maxLeft;
            if (_fabTop! > maxTop) _fabTop = maxTop;
          });
        },
        onPanEnd: (_) {
          final double currentLeft = (_fabLeft ?? initialLeft).clamp(margin, maxLeft);
          final double currentTop = (_fabTop ?? initialTop).clamp(topSafeMargin, maxTop);
          final bool snapLeft = (currentLeft - margin).abs() <= (maxLeft - currentLeft).abs();
          setState(() {
            _fabLeft = snapLeft ? margin : maxLeft;
            _fabTop = currentTop;
            _isDragging = false;
          });
        },
        child: _buildMyAfyaAiFab(context),
      ),
    );
  }

  // Méthodes pour gérer les actions des différentes pages
  void _handleForumActions(String action) {
    switch (action) {
      case 'add_post':
        // Action pour ajouter un nouveau post
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fonctionnalité d\'ajout de post à implémenter')),
        );
        break;
      case 'search':
        // Action pour rechercher
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fonctionnalité de recherche à implémenter')),
        );
        break;
    }
  }

  void _handleRendezvousActions(String action) {
    switch (action) {
      case 'add_rendezvous':
        // Action pour ajouter un rendez-vous
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fonctionnalité d\'ajout de rendez-vous à implémenter')),
        );
        break;
      case 'calendar_view':
        // Action pour vue calendrier
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vue calendrier à implémenter')),
        );
        break;
    }
  }

  void _handleHistoriqueActions(String action) {
    switch (action) {
      case 'filter':
        // Action pour filtrer
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fonctionnalité de filtrage à implémenter')),
        );
        break;
      case 'download':
        // Action pour télécharger
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fonctionnalité de téléchargement à implémenter')),
        );
        break;
    }
  }

}

class ContactListScreen extends StatelessWidget {
  const ContactListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          Set<String> contacts = {};
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            String contact = data['receiverId'];
            contacts.add(contact);
          }

          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts.elementAt(index);
              return _buildContactTile(context, contact);
            },
          );
        },
      ),
    );
  }

  Widget _buildContactTile(BuildContext context, String contact) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: contact)
          .where('receiverId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('messages')
              .where('senderId', isEqualTo: contact)
              .where('receiverId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .snapshots(),
          builder: (context, lastMessageSnapshot) {
            String lastMessage = '';
            DateTime? lastMessageTime;

            if (lastMessageSnapshot.hasData && lastMessageSnapshot.data!.docs.isNotEmpty) {
              final data = lastMessageSnapshot.data!.docs.first.data() as Map<String, dynamic>;
              lastMessage = data['message'] ?? '';
              lastMessageTime = (data['timestamp'] as Timestamp?)?.toDate();
            }

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  radius: 24,
                  child: Text(
                    contact.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                title: Text(
                  contact,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unreadCount > 0 ? Colors.black : Colors.grey[600],
                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (lastMessageTime != null)
                      Text(
                        _formatTime(lastMessageTime),
                        style: TextStyle(
                          color: unreadCount > 0 ? Colors.blueAccent : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    if (unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    print("Utilisateur non connecté");
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(contactName: contact),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return DateFormat('dd/MM').format(time);
    } else {
      return DateFormat('HH:mm').format(time);
    }
  }
}

class ChatPage extends StatefulWidget {
  final String contactName;

  const ChatPage({super.key, required this.contactName});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isAttaching = false;
  final List<String> _quickReplies = [
    "Bonjour, comment puis-je vous aider ?",
    "Je suis disponible pour une consultation.",
    "Pouvez-vous me donner plus de détails ?",
    "Je vous recontacterai bientôt.",
    "Merci de votre patience.",
  ];

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    _updateTypingStatus(true);
  }

  @override
  void dispose() {
    _updateTypingStatus(false);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateTypingStatus(bool isTyping) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'isTyping': isTyping,
        'typingTo': isTyping ? widget.contactName : null,
      });
    }
  }

  void _markMessagesAsRead() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: widget.contactName)
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.update({'isRead': true});
        }
      });
    }
  }

  void _sendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final message = _controller.text.trim();
      if (message.isNotEmpty) {
        await FirebaseFirestore.instance.collection('messages').add({
          'senderId': currentUser.uid,
          'receiverId': widget.contactName,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
        _controller.clear();
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showQuickReplies() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Réponses rapides',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickReplies.map((reply) {
                  return ActionChip(
                    label: Text(reply),
                    onPressed: () {
                      _controller.text = reply;
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showAttachmentOptions() {
    setState(() {
      _isAttaching = true;
    });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Joindre un fichier',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text('Image'),
                onTap: () {
                  // Implémenter la sélection d'image
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: Colors.blue),
                title: const Text('Document'),
                onTap: () {
                  // Implémenter la sélection de document
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic, color: Colors.blue),
                title: const Text('Audio'),
                onTap: () {
                  // Implémenter l'enregistrement audio
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((_) {
      setState(() {
        _isAttaching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 16,
              child: Text(
                widget.contactName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.contactName),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.contactName)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final isTyping = data['isTyping'] ?? false;
                      final typingTo = data['typingTo'];

                      if (isTyping && typingTo == FirebaseAuth.instance.currentUser?.uid) {
                        return const Text(
                          'En train d\'écrire...',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Afficher les options supplémentaires
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .where('senderId', whereIn: [
                    FirebaseAuth.instance.currentUser?.uid,
                    widget.contactName
                  ])
                  .where('receiverId', whereIn: [
                    FirebaseAuth.instance.currentUser?.uid,
                    widget.contactName
                  ])
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun message',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Commencez la conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var data = messages[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                    Timestamp? timestamp = data['timestamp'] as Timestamp?;
                    DateTime? messageTime = timestamp?.toDate();

                    // Vérifier si nous devons afficher la date
                    bool showDate = false;
                    if (index == 0 || index > 0) {
                      if (index == 0) {
                        showDate = true;
                      } else {
                        var prevData = messages[index - 1].data() as Map<String, dynamic>;
                        Timestamp? prevTimestamp = prevData['timestamp'] as Timestamp?;
                        DateTime? prevMessageTime = prevTimestamp?.toDate();

                        if (messageTime != null && prevMessageTime != null) {
                          if (messageTime.day != prevMessageTime.day ||
                              messageTime.month != prevMessageTime.month ||
                              messageTime.year != prevMessageTime.year) {
                            showDate = true;
                          }
                        }
                      }
                    }

                    return Column(
                      children: [
                        if (showDate && messageTime != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDate(messageTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blueAccent : Colors.grey[300],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['message'],
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                                if (messageTime != null)
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      _formatTime(messageTime),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe ? Colors.white70 : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Column(
              children: [
                if (_isTyping)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                    child: Row(
                      children: [
                        Text(
                          'Vous êtes en train d\'écrire...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _showAttachmentOptions,
                      color: _isAttaching ? Colors.blueAccent : Colors.grey[600],
                    ),
                    IconButton(
                      icon: const Icon(Icons.reply),
                      onPressed: _showQuickReplies,
                      color: Colors.grey[600],
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Entrez un message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (text) {
                          setState(() {
                            _isTyping = text.isNotEmpty;
                          });
                          _updateTypingStatus(text.isNotEmpty);
                        },
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Aujourd\'hui';
    } else if (messageDate == yesterday) {
      return 'Hier';
    } else {
      return DateFormat('dd MMMM yyyy').format(date);
    }
  }
}
