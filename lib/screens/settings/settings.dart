import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_virtuel/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../login_screen.dart';
import '../patient/dossier_medical_markdown.dart';
import 'package:share_plus/share_plus.dart';
import '../patient/politique.dart';
import '../doctor/politique.dart';
import 'abonnement.dart';
import 'change_password.dart';
import 'historique.dart';
import 'problem_reports.dart';
import 'feedback_page.dart';
import 'politique_confidentialite_page.dart';
import 'guide_utilisateur_page.dart';
import 'package:hospital_virtuel/services/auth_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _inviteFriends() {
    String appLink = "https://www.example.com";
    String message =
        "Rejoignez-nous sur Hospital Virtuel ! Téléchargez l'application ici : $appLink";
    Share.share(message, subject: 'Invitation à Hospital Virtuel');
  }

  void _reportProblem(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProblemReportsPage()),
    );
  }

  void _logout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Déconnexion'),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Se déconnecter',
                  style: TextStyle(color: Colors.red.shade700)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Utiliser le nouveau service d'authentification qui nettoie le cache
      await AuthService.signOut();
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false);
    }
  }

  Future<bool> _isUserDoctor() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .get();
      return docSnapshot.exists;
    }
    return false;
  }

  void _redirectToPolitique(BuildContext context) async {
    bool isDoctor = await _isUserDoctor();
    if (isDoctor) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PolitiquePage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PolitiquePatientPage()),
      );
    }
  }


  void _redirectToDossierMedicalMarkdown(BuildContext context) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter pour voir votre dossier.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      Navigator.pop(context);

      String patientFullName = 'Patient';
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        String prenom = data['prenom'] ?? data['first_name'] ?? '';
        String nom = data['nom'] ?? data['last_name'] ?? '';
        String postnom = data['postnom'] ?? '';
        patientFullName =
            [prenom, nom, postnom].where((s) => s.isNotEmpty).join(' ');
      }

      if (patientFullName.isEmpty) {
        patientFullName =
            currentUser.displayName ?? currentUser.email ?? 'Patient';
      }

      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => DossierMedicalMarkdownPage(
                    patientId: currentUser.uid,
                    patientName: patientFullName,
                  )));
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement des données: $e')),
      );
    }
  }


  void _redirectToPolitiqueConfidentialite(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PolitiqueConfidentialitePage()),
    );
  }

  void _redirectToGuideUtilisateur(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GuideUtilisateurPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 768;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          'Paramètres',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isDesktop ? 24 : 20,
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
      backgroundColor: isDarkMode ? Colors.black : Theme.of(context).colorScheme.surface,
      body: FutureBuilder<bool>(
        future: _isUserDoctor(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.blue.shade400 : Colors.blue.shade600,
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Erreur: ${snapshot.error}",
                style: TextStyle(
                  color: isDarkMode ? Colors.red.shade400 : Colors.red.shade600,
                ),
              ),
            );
          }

          bool isDoctor = snapshot.data ?? false;

          return isDesktop ? _buildDesktopLayout(context, isDarkMode, isDoctor) : _buildMobileLayout(context, isDarkMode, isDoctor);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool isDarkMode, bool isDoctor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode 
            ? [Colors.black, Colors.grey.shade900]
            : [Colors.grey.shade50, Colors.white],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              elevation: 12,
              shadowColor: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.2),
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(40.0),
                child: SingleChildScrollView(
                  child: _buildSettingsList(context, isDarkMode, isDoctor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isDarkMode, bool isDoctor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode 
            ? [Colors.black, Colors.grey.shade900]
            : [Colors.grey.shade50, Colors.white],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _buildSettingsList(context, isDarkMode, isDoctor),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, bool isDarkMode, bool isDoctor) {
    return Column(
      children: [
        _buildSettingsCard(
          context: context,
          icon: Icons.security_outlined,
          title: 'Sécurité',
          subtitle: 'Modifier votre mot de passe',
          isDarkMode: isDarkMode,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage()),
            );
          },
        ),
        _buildSettingsCard(
          context: context,
          icon: Icons.privacy_tip_outlined,
          title: 'Politique de confidentialité',
          subtitle: 'Protection de vos données personnelles',
          isDarkMode: isDarkMode,
          onTap: () => _redirectToPolitiqueConfidentialite(context),
        ),
        _buildSettingsCard(
          context: context,
          icon: Icons.report_problem_outlined,
          title: 'Signaler un problème',
          isDarkMode: isDarkMode,
          onTap: () => _reportProblem(context),
        ),
        _buildSettingsCard(
          context: context,
          icon: Icons.brightness_6_outlined,
          title: 'Mode sombre',
          isDarkMode: isDarkMode,
          trailing: Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme(value);
                },
                activeColor: isDarkMode ? Colors.blue.shade400 : Colors.blue.shade600,
              );
            },
          ),
        ),
        if (!isDoctor) ...[
          _buildSettingsCard(
            context: context,
            icon: Icons.medical_information_outlined,
            title: 'Mon Dossier Médical',
            subtitle: 'Consulter et modifier vos informations médicales',
            isDarkMode: isDarkMode,
            onTap: () => _redirectToDossierMedicalMarkdown(context),
          ),
          _buildSettingsCard(
            context: context,
            icon: Icons.feedback_outlined,
            title: 'Donner votre avis',
            subtitle: 'Partagez vos suggestions ou appréciations',
            isDarkMode: isDarkMode,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FeedbackPage()),
              );
            },
          ),
        ],
        _buildSettingsCard(
          context: context,
          icon: Icons.help_outline,
          title: 'Guide d\'Utilisateur',
          subtitle: 'Documentation complète de la plateforme',
          isDarkMode: isDarkMode,
          onTap: () => _redirectToGuideUtilisateur(context),
        ),
        _buildSettingsCard(
          context: context,
          icon: Icons.share_outlined,
          title: 'Inviter des amis',
          isDarkMode: isDarkMode,
          onTap: _inviteFriends,
        ),
        const SizedBox(height: 20),
        _buildSettingsCard(
          context: context,
          icon: Icons.exit_to_app_rounded,
          title: 'Se déconnecter',
          isDarkMode: isDarkMode,
          onTap: () => _logout(context),
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isDestructive = false,
    bool isDarkMode = false,
  }) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: isDarkMode ? Colors.grey.shade700 : Colors.white,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        leading: Icon(
          icon,
          color: isDestructive 
              ? Colors.red.shade400
              : isDarkMode ? Colors.blue.shade400 : Colors.blue.shade600,
          size: 28
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDestructive
                ? Colors.red.shade400
                : isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle, 
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600
                )
              )
            : null,
        trailing: trailing ??
            (onTap != null
                ? Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16, 
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600
                  )
                : null),
        onTap: onTap,
      ),
    );
  }
}
