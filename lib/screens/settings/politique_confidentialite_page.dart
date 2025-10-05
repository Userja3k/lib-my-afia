import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PolitiqueConfidentialitePage extends StatelessWidget {
  const PolitiqueConfidentialitePage({super.key});

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
          'Politique de Confidentialité',
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
                Icons.privacy_tip_outlined,
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
                    'Politique de Confidentialité',
                    style: GoogleFonts.lato(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    'Protection de vos données personnelles et médicales',
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
            'Introduction',
            'Hospital Virtuel (Afya Bora) s\'engage à protéger votre vie privée et vos données personnelles. Cette politique de confidentialité explique comment nous collectons, utilisons, stockons et protégeons vos informations.',
            isDarkMode,
          ),
          _buildSection(
            'Responsable du Traitement',
            'Hospital Virtuel (Afya Bora)\nEmail : privacy@hospitalvirtuel.com\nDélégué à la Protection des Données : dpo@hospitalvirtuel.com',
            isDarkMode,
          ),
          _buildSection(
            'Données Collectées',
            '• Données d\'identification (nom, email, téléphone)\n• Données médicales (symptômes, diagnostics, traitements)\n• Données techniques (adresse IP, type d\'appareil)\n• Photos médicales (avec votre consentement)',
            isDarkMode,
          ),
          _buildSection(
            'Finalités du Traitement',
            '• Consultations virtuelles avec des professionnels de santé\n• Gestion du dossier médical personnel\n• Rappels de médicaments et suivi des traitements\n• Communication entre patients et médecins',
            isDarkMode,
          ),
          _buildSection(
            'Sécurité des Données',
            '• Chiffrement AES-256 pour toutes les données\n• Authentification à deux facteurs\n• Sauvegarde sécurisée et redondante\n• Surveillance continue des accès',
            isDarkMode,
          ),
          _buildSection(
            'Vos Droits',
            '• Droit d\'accès à vos données\n• Droit de rectification\n• Droit à l\'effacement\n• Droit à la portabilité\n• Droit d\'opposition',
            isDarkMode,
          ),
          _buildSection(
            'Contact',
            'Pour toute question concernant cette politique de confidentialité :\nEmail : dpo@hospitalvirtuel.com\n\nCette politique est conforme au RGPD et aux réglementations en vigueur.',
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
