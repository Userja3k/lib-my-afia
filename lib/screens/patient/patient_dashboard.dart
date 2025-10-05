import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:hospital_virtuel/screens/patient/pharmacy_page.dart';
import 'package:hospital_virtuel/screens/patient/emergency_page.dart';
import 'package:hospital_virtuel/screens/patient/article_page.dart';
import 'package:hospital_virtuel/screens/patient/soins_page.dart';
import 'package:hospital_virtuel/screens/doctor/chat.dart' as chat_ai;
import 'package:hospital_virtuel/screens/settings/settings.dart';
import 'package:hospital_virtuel/screens/patient/symptomes.dart';
import 'package:hospital_virtuel/screens/patient/home_consultation.dart';
import 'package:hospital_virtuel/screens/patient/rendezvous.dart';
import 'package:hospital_virtuel/screens/patient/appointment_page.dart';
import 'package:hospital_virtuel/screens/patient/doctors_list_page.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const PatientDashboardContent(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PatientDashboardContent extends StatefulWidget {
  const PatientDashboardContent({super.key});

  @override
  State<PatientDashboardContent> createState() => _PatientDashboardContentState();
}

class _PatientDashboardContentState extends State<PatientDashboardContent> {
  int _currentIndex = 0;
  bool _isDesktop = false;
  double? _fabLeft;
  double? _fabTop;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScreenSize();
    });
  }

  void _checkScreenSize() {
    final mediaQuery = MediaQuery.of(context);
    setState(() {
      _isDesktop = mediaQuery.size.width >= 768;
    });
  }

  void _navigateToConsultationsTab() {
    setState(() {
      _currentIndex = 1;
    });
  }

  final Map<String, IconData> specialtyIcons = {
    'Médecine Générale': Icons.medical_services_outlined,
    'Cardiologie': Icons.favorite_border_outlined,
    'Dermatologie': Icons.healing_outlined,
    'Pédiatrie': Icons.child_care_outlined,
    'Gynécologie': Icons.pregnant_woman_outlined,
    'Psychologie': Icons.self_improvement_outlined,
    'Psychiatrie': Icons.psychology_outlined,
    'Nutrition': Icons.restaurant_menu_outlined,
    'Neurologie': Icons.psychology_outlined,
    'Médecine Sportive': Icons.fitness_center_outlined,
    'Médecine du Travail': Icons.work_outline,
    'Allergologie': Icons.masks_outlined,
    'Endocrinologie': Icons.science_outlined,
    'Urologie': Icons.male_outlined,
  };

  Stream<int> _getUnreadMessagesCountStream() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    final bool showMainAppBar = _currentIndex == 1 && !_isDesktop;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 768 != _isDesktop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _isDesktop = constraints.maxWidth >= 768;
            });
          });
        }

        if (_isDesktop) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout(showMainAppBar);
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    final theme = Theme.of(context);
    
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
                const SizedBox(height: 60),
                // Boutons du menu latéral
                _buildDesktopNavButton(Icons.article_outlined, 0, 'Articles'),
                _buildDesktopNavButton(Icons.medical_services_outlined, 1, 'Consultation'),
                _buildDesktopNavButtonWithBadge(Icons.healing_outlined, 2, 'Soins'),
                _buildDesktopNavButton(Icons.local_pharmacy_outlined, 3, 'Pharmacie'),
                _buildDesktopNavButton(Icons.phone_outlined, 4, 'Urgences'),
                const Spacer(),
                // Bouton Paramètres
                IconButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
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
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final content = Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Card(
                            elevation: 4.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _getPage(_currentIndex)),
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

  Widget _buildDesktopNavButton(IconData icon, int index, String tooltip) {
    final isSelected = _currentIndex == index;
    
    return Column(
      children: [
        IconButton(
          icon: Icon(icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 30),
          onPressed: () => setState(() => _currentIndex = index),
          tooltip: tooltip,
        ),
        Text(tooltip,
            style: GoogleFonts.roboto(
                fontSize: 10,
                color: isSelected ? Colors.white : Colors.white70)),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildDesktopNavButtonWithBadge(IconData icon, int index, String tooltip) {
    final isSelected = _currentIndex == index;
    
    return StreamBuilder<int>(
      stream: _getUnreadMessagesCountStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        return Column(
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: Icon(icon,
                      color: isSelected ? Colors.white : Colors.white70,
                      size: 30),
                  onPressed: () => setState(() => _currentIndex = index),
                  tooltip: tooltip,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            Text(tooltip,
                style: GoogleFonts.roboto(
                    fontSize: 10,
                    color: isSelected ? Colors.white : Colors.white70)),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildMobileLayout(bool showMainAppBar) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: showMainAppBar
          ? AppBar(
              systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
              title: Text(
                _getAppBarTitle(),
                style: GoogleFonts.lato(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
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
                ),
              ],
            )
          : null,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = _getPage(_currentIndex);
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
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade800,
        unselectedItemColor: Colors.blueGrey.shade500,
        selectedLabelStyle: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 12.5),
        unselectedLabelStyle: GoogleFonts.roboto(fontSize: 12),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: 'Articles',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.medical_services_outlined),
            label: 'Consultation',
          ),
          BottomNavigationBarItem(
            icon: _buildSoinsIconWithBadge(),
            label: 'Soins',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.local_pharmacy_outlined),
            label: 'Pharmacie',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.phone_outlined),
            label: 'Urgences',
          ),
        ],
      ),
    );
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
      backgroundColor: Colors.blue,
    );
  }

  Widget _buildDraggableFab(BuildContext context, BoxConstraints constraints) {
    const double fabSize = 56;
    const double margin = 8;
    final mediaQuery = MediaQuery.of(context);
    final double statusBar = mediaQuery.padding.top;
    final double topSafeMargin = (_isDesktop ? 96.0 : kToolbarHeight) + statusBar;
    final maxLeft = constraints.maxWidth - fabSize - margin;
    final maxTop = constraints.maxHeight - fabSize - margin;
    final initialLeft = _fabLeft ?? maxLeft;
    final initialTop = _fabTop ?? maxTop;

    return AnimatedPositioned(
      left: (_fabLeft ?? initialLeft),
      top: (_fabTop ?? initialTop),
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutQuad,
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

          final double dLeft = (currentLeft - margin).abs();
          final double dRight = (maxLeft - currentLeft).abs();
          final double dTop = (currentTop - topSafeMargin).abs();
          final double dBottom = (maxTop - currentTop).abs();

          // Trouver le bord le plus proche
          final List<double> distances = [dLeft, dRight, dTop, dBottom];
          final int minIndex = distances.indexOf(distances.reduce((a, b) => a < b ? a : b));

          setState(() {
            switch (minIndex) {
              case 0: // gauche
                _fabLeft = margin;
                _fabTop = currentTop;
                break;
              case 1: // droite
                _fabLeft = maxLeft;
                _fabTop = currentTop;
                break;
              case 2: // haut
                _fabTop = topSafeMargin;
                _fabLeft = currentLeft;
                break;
              case 3: // bas
              default:
                _fabTop = maxTop;
                _fabLeft = currentLeft;
                break;
            }
            _isDragging = false;
          });
        },
        child: _buildMyAfyaAiFab(context),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0: return 'Articles';
      case 1: return 'Consultation';
      case 2: return 'Soins';
      case 3: return 'Pharmacie';
      case 4: return 'Urgences';
      default: return 'Afya Bora';
    }
  }

  Widget _buildSoinsIconWithBadge() {
    return StreamBuilder<int>(
      stream: _getUnreadMessagesCountStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        if (unreadCount > 0) {
          return Badge(
            label: Text(unreadCount > 9 ? '9+' : '$unreadCount',
                style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.red.shade600,
            child: const Icon(Icons.healing_outlined),
          );
        }
        return const Icon(Icons.healing_outlined);
      },
    );
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0: return ArticlePage(isDesktop: _isDesktop);
      case 1: return _buildHomePage();
      // On passe l'état du layout à la page de soins
      case 2: return SoinsPage(onNavigateToConsultations: _navigateToConsultationsTab, isDesktop: _isDesktop);
      case 3: return PharmacyPage();
      case 4: return EmergencyPage(isDesktop: _isDesktop);
      default: return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(_isDesktop ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            _buildConsultationCard(),
            const SizedBox(height: 24),
            _buildSpecialtiesCard(),
            const SizedBox(height: 24),
            _buildHomeConsultationCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationCard() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: _isDesktop ? 8 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_isDesktop ? 20 : 15)),
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        child: Padding(
          padding: EdgeInsets.all(_isDesktop ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.online_prediction_rounded, color: Colors.blue.shade700, size: _isDesktop ? 32 : 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Consultation en ligne',
                      style: GoogleFonts.lato(
                        fontSize: _isDesktop ? 24 : 20,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Décrivez vos symptômes pour une évaluation rapide et des conseils adaptés.',
                style: GoogleFonts.roboto(
                  fontSize: _isDesktop ? 16 : 14.5,
                  color: isDarkMode ? Colors.grey.shade300 : Colors.blueGrey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: _isDesktop ? 56 : 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SymptomesPage(doctorId: 'doctorId')),
                    );
                  },
                  icon: const Icon(Icons.checklist_rtl_rounded, size: 20, color: Colors.white),
                  label: Text(
                    'Décrire mes symptômes',
                    style: GoogleFonts.lato(fontSize: _isDesktop ? 16 : 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_isDesktop ? 12 : 10),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialtiesCard() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: _isDesktop ? 8 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_isDesktop ? 20 : 15)),
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        child: Padding(
          padding: EdgeInsets.all(_isDesktop ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.category_rounded, color: Colors.blue.shade700, size: _isDesktop ? 32 : 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Nos Spécialités',
                      style: GoogleFonts.lato(
                        fontSize: _isDesktop ? 24 : 20,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: _isDesktop ? 180 : 135,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: specialtyIcons.length,
                  itemBuilder: (context, index) {
                    final entry = specialtyIcons.entries.elementAt(index);
                    final isDarkMode = theme.brightness == Brightness.dark;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isDesktop ? 160 : 140,
                        child: Card(
                          elevation: 3,
                          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DoctorsListPage(
                                    specialty: entry.key,
                                    isDesktop: _isDesktop,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      entry.value,
                                      size: _isDesktop ? 32 : 28,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    entry.key,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.roboto(
                                      fontSize: _isDesktop ? 13 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode ? Colors.white : Colors.blueGrey.shade700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeConsultationCard() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: _isDesktop ? 8 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_isDesktop ? 20 : 15)),
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        child: Padding(
          padding: EdgeInsets.all(_isDesktop ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.home_work_rounded, color: Colors.blue.shade700, size: _isDesktop ? 32 : 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Consultation à Domicile',
                      style: GoogleFonts.lato(
                        fontSize: _isDesktop ? 24 : 20,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Besoin d\'une consultation chez vous ? Planifiez une visite.',
                style: GoogleFonts.roboto(
                  fontSize: _isDesktop ? 16 : 14.5,
                  color: isDarkMode ? Colors.grey.shade300 : Colors.blueGrey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: _isDesktop ? 56 : 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeConsultationPage()),
                    );
                  },
                  icon: const Icon(Icons.event_available_rounded, size: 20, color: Colors.white),
                  label: Text(
                    'Demander une visite',
                    style: GoogleFonts.lato(fontSize: _isDesktop ? 16 : 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_isDesktop ? 12 : 10),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        String userName = "Patient";
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          userName = data['first_name'] ?? user.displayName ?? "Patient";
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: EdgeInsets.symmetric(horizontal: _isDesktop ? 32.0 : 20, vertical: _isDesktop ? 32.0 : 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade100,
                Colors.lightBlue.shade50,
                Colors.blue.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_isDesktop ? 20 : 15),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.15),
                blurRadius: _isDesktop ? 20 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.waving_hand_rounded, color: Colors.amber.shade800, size: _isDesktop ? 44 : 36),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        snapshot.connectionState == ConnectionState.waiting 
                            ? 'Bonjour...' 
                            : 'Bonjour, $userName !',
                        key: ValueKey<String>(userName),
                        style: GoogleFonts.lato(
                          fontSize: _isDesktop ? 28 : 22, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.blueGrey.shade800),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Comment pouvons-nous vous aider aujourd\'hui ?',
                      style: GoogleFonts.roboto(
                        fontSize: _isDesktop ? 16 : 14,
                        color: Colors.blueGrey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}