import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PolitiquePage extends StatefulWidget {
  const PolitiquePage({super.key});

  @override
  _PolitiquePageState createState() => _PolitiquePageState();
}

class _PolitiquePageState extends State<PolitiquePage> {
  bool _hasAcceptedPolicy = false;

  @override
  void initState() {
    super.initState();
    _checkIfAcceptedPolicy();
  }

  // Vérifie si l'utilisateur a déjà accepté la politique de confidentialité
  Future<void> _checkIfAcceptedPolicy() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasAcceptedPolicy = prefs.getBool('hasAcceptedPolicy') ?? false;
    });
  }

  // Sauvegarde l'acceptation de la politique de confidentialité
  Future<void> _acceptPolicy() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasAcceptedPolicy', true);
    Navigator.pop(context); // Redirige vers la page précédente
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Politique de Confidentialité', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      _buildPolicySection(
                        context,
                        '1. Introduction',
                        'Chez Afya Bora, nous nous engageons à protéger vos informations personnelles et professionnelles. '
                        'Cette politique de confidentialité explique comment nous collectons, utilisons et protégeons vos données en tant que médecin.',
                      ),
                      _buildPolicySection(
                        context,
                        '2. Collecte des données',
                        'Nous collectons des informations comme votre nom, adresse e-mail, spécialité médicale, qualifications, et les informations des consultations que vous gérez.',
                      ),
                      _buildPolicySection(
                        context,
                        '3. Utilisation des données',
                        'Vos données sont utilisées pour faciliter la gestion des consultations, améliorer les services et respecter les obligations légales en matière de santé.',
                      ),
                      _buildPolicySection(
                        context,
                        '4. Protection des données',
                        'Nous mettons en place des mesures de sécurité pour protéger vos informations contre tout accès non autorisé.',
                      ),
                      _buildPolicySection(
                        context,
                        '5. Partage des données',
                        'Vos données peuvent être partagées avec les patients, ou avec des prestataires de services tiers pour la gestion technique.',
                      ),
                      _buildPolicySection(
                        context,
                        '6. Vos droits',
                        'Vous avez le droit d\'accéder, de corriger ou de supprimer vos données personnelles selon les législations en vigueur.',
                      ),
                      _buildPolicySection(
                        context,
                        '7. Contact',
                        'Pour toute question ou pour exercer vos droits, contactez-nous à support@hospitalvirtuel.com.', // Email mis à jour
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Vérifie si l'utilisateur a déjà accepté la politique
            if (_hasAcceptedPolicy)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Vous avez déjà accepté la politique de confidentialité.',
                      style: TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Fermer'),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: _acceptPolicy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('J\'ai lu et j\'accepte la politique'),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue[700]),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
