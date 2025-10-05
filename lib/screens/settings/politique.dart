import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_virtuel/screens/signup_screen.dart';

class PolitiquePage extends StatefulWidget {
  const PolitiquePage({super.key});

  @override
  _PolitiquePageState createState() => _PolitiquePageState();
}

class _PolitiquePageState extends State<PolitiquePage> {
  bool _isPolicyAccepted = false;

  Future<void> _acceptPolicy(BuildContext context) async {
    if (_isPolicyAccepted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('policy_accepted', true);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignupScreen()),
        );
      }
    }
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
          'Politique de confidentialité',
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
      child: Padding(
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
                    'Politique de confidentialité',
                    style: GoogleFonts.lato(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    'Protection de vos données personnelles',
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
        
        // Contenu de la politique
        _buildPolicyContent(isDarkMode),
        
        const SizedBox(height: 30),
        
        // Section d'acceptation
        _buildAcceptanceSection(isDarkMode),
      ],
    );
  }

  Widget _buildPolicyContent(bool isDarkMode) {
    return Column(
      children: [
        _buildPolicySection(
          '1. Collecte des données',
          'Nous collectons uniquement les informations nécessaires au bon fonctionnement de l\'application.',
          isDarkMode,
        ),
        _buildPolicySection(
          '2. Utilisation des données',
          'Vos données sont utilisées exclusivement pour vous fournir nos services médicaux.',
          isDarkMode,
        ),
        _buildPolicySection(
          '3. Partage des données',
          'Nous ne partageons jamais vos informations personnelles avec des tiers sans votre consentement.',
          isDarkMode,
        ),
        _buildPolicySection(
          '4. Protection des données',
          'Nous mettons en place des mesures de sécurité pour protéger vos informations personnelles.',
          isDarkMode,
        ),
        _buildPolicySection(
          '5. Contact',
          'Si vous avez des questions concernant notre politique de confidentialité, contactez-nous à support@hospitalvirtuel.com.',
          isDarkMode,
        ),
      ],
    );
  }

  Widget _buildAcceptanceSection(bool isDarkMode) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.blue.withOpacity(0.2))
          ),
          child: Row(
            children: [
              Checkbox(
                value: _isPolicyAccepted,
                activeColor: Colors.blue,
                onChanged: (bool? value) {
                  setState(() {
                    _isPolicyAccepted = value ?? false;
                  });
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                     setState(() {
                      _isPolicyAccepted = !_isPolicyAccepted;
                    });
                  },
                  child: Text(
                    'J\'ai lu et j\'accepte la politique de confidentialité.',
                    style: GoogleFonts.roboto(
                      fontSize: 15,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isPolicyAccepted 
                ? [Colors.blue.shade600, Colors.blue.shade500]
                : [Colors.grey.shade400, Colors.grey.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: _isPolicyAccepted ? () => _acceptPolicy(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Continuer',
              style: GoogleFonts.lato(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPolicySection(String title, String content, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
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
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.roboto(
              fontSize: 14,
              height: 1.5,
              color: isDarkMode ? Colors.grey.shade300 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
