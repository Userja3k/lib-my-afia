import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class GuideUtilisateurPage extends StatelessWidget {
  const GuideUtilisateurPage({super.key});

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
          'Guide d\'Utilisateur',
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
      body: isDesktop ? _buildDesktopLayout(isDarkMode) : _buildMobileLayout(isDarkMode),
    );
  }

  Widget _buildDesktopLayout(bool isDarkMode) {
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
                child: _buildContent(isDarkMode),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDarkMode) {
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
        child: _buildContent(isDarkMode),
      ),
    );
  }

  Widget _buildContent(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.help_outline,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guide d\'Utilisateur',
                    style: GoogleFonts.lato(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    'Tout ce que vous devez savoir sur Hospital Virtuel',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        
        // Contenu simple
        _buildSimpleContent(isDarkMode),
      ],
    );
  }

  Widget _buildSimpleContent(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            'Bienvenue sur Hospital Virtuel',
            'Hospital Virtuel (Afya Bora) est une plateforme de télémédecine complète qui vous permet de consulter des médecins à distance, gérer vos médicaments et accéder à des soins de santé de qualité, 24h/24.',
            isDarkMode,
          ),
          _buildSection(
            'Fonctionnalités Principales',
            '• Consultations virtuelles en temps réel\n• Rappels de médicaments automatisés\n• Gestion des rendez-vous en ligne\n• Pharmacie virtuelle intégrée\n• Service d\'urgence avec géolocalisation\n• Articles de santé et conseils',
            isDarkMode,
          ),
          _buildSection(
            'Pour les Patients - Connexion',
            '1. Téléchargez l\'application depuis l\'App Store ou Google Play\n2. Ouvrez l\'application et cliquez sur "S\'inscrire"\n3. Remplissez le formulaire avec vos informations\n4. Vérifiez votre email\n5. Connectez-vous avec vos identifiants',
            isDarkMode,
          ),
          _buildSection(
            'Consultation Virtuelle',
            '1. Cliquez sur "Nouvelle consultation"\n2. Sélectionnez la spécialité médicale\n3. Choisissez un médecin disponible\n4. Sélectionnez une date et heure\n5. Confirmez votre rendez-vous\n6. Recevez une confirmation par email/SMS',
            isDarkMode,
          ),
          _buildSection(
            'Gestion des Médicaments',
            '• Recevez des notifications à l\'heure de prise\n• Confirmez la prise de médicament\n• Consultez l\'historique des prises\n• Ajustez les horaires si nécessaire\n• Ajoutez de nouveaux médicaments',
            isDarkMode,
          ),
          _buildSection(
            'Service d\'Urgence',
            '1. Cliquez sur le bouton d\'urgence (rouge)\n2. Confirmez votre localisation\n3. Décrivez brièvement l\'urgence\n4. Recevez les instructions d\'urgence\n5. Contactez les services d\'urgence locaux',
            isDarkMode,
          ),
          _buildSection(
            'Pour les Médecins',
            '• Connexion avec identifiants professionnels\n• Gestion des consultations en temps réel\n• Communication avec les patients\n• Prescription électronique\n• Création de rappels de médicaments\n• Forum médical professionnel',
            isDarkMode,
          ),
          _buildSection(
            'Paramètres et Configuration',
            '• Modification du profil utilisateur\n• Changement de mot de passe\n• Mode sombre/clair\n• Configuration des notifications\n• Gestion des sessions actives',
            isDarkMode,
          ),
          _buildSection(
            'FAQ - Questions Fréquentes',
            'Q : Comment réinitialiser mon mot de passe ?\nR : Cliquez sur "Mot de passe oublié" sur l\'écran de connexion.\n\nQ : Puis-je annuler un rendez-vous ?\nR : Oui, jusqu\'à 24h avant le rendez-vous.\n\nQ : Mes données sont-elles sécurisées ?\nR : Oui, toutes vos données sont chiffrées et protégées.',
            isDarkMode,
          ),
          _buildSection(
            'Support et Contact',
            '• Email : support@hospitalvirtuel.com\n• Téléphone : [Numéro de support]\n• Chat en ligne (24h/24)\n• Forum communautaire\n• Signaler un problème dans les paramètres',
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, bool isDarkMode) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.roboto(
              fontSize: 14,
              height: 1.6,
              color: isDarkMode ? Colors.grey.shade300 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
