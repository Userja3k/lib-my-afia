import 'package:flutter/material.dart';

class PolitiquePatientPage extends StatelessWidget {
  const PolitiquePatientPage({super.key});

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
                  'Chez Afya Bora, nous respectons votre vie privée et nous nous engageons à protéger vos informations personnelles et médicales. '
                  'Cette politique de confidentialité décrit comment nous collectons, utilisons et protégeons vos données en tant que patient.',
                ),
                _buildPolicySection(
                  context,
                  '2. Collecte des données',
                  'Nous collectons des informations telles que votre nom, adresse e-mail, historique médical, rendez-vous et résultats de consultations.',
                ),
                _buildPolicySection(
                  context,
                  '3. Utilisation des données',
                  'Vos données sont utilisées pour organiser vos consultations, suivre votre historique médical et améliorer nos services de soins à distance.',
                ),
                _buildPolicySection(
                  context,
                  '4. Protection des données',
                  'Nous mettons en œuvre des mesures de sécurité pour protéger vos données contre tout accès non autorisé, conformément aux normes en matière de confidentialité des données médicales.',
                ),
                _buildPolicySection(
                  context,
                  '5. Partage des données',
                  'Vos informations peuvent être partagées uniquement avec vos médecins traitants ou des prestataires de services tiers dans le cadre de la gestion de vos soins médicaux.',
                ),
                _buildPolicySection(
                  context,
                  '6. Vos droits',
                  'Vous avez le droit d\'accéder à vos données personnelles, de les corriger ou de demander leur suppression, conformément aux lois de protection des données.',
                ),
                _buildPolicySection(
                  context,
                  '7. Contact',
                  'Si vous avez des questions concernant cette politique ou vos droits, veuillez nous contacter à support@hospitalvirtuel.com.', // J'ai remplacé [nomdelhopital] par hospitalvirtuel
                ),
              ],
            ),
          ),
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
