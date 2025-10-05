import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class OrdonnancesPage extends StatefulWidget {
  const OrdonnancesPage({super.key});

  @override
  _OrdonnancesPageState createState() => _OrdonnancesPageState();
}

class _OrdonnancesPageState extends State<OrdonnancesPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Future<List<Map<String, String>>> _ordonnancesFuture;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _ordonnancesFuture = _fetchOrdonnances();
    } else {
      _ordonnancesFuture = Future.value([]);
    }
  }

  Future<List<Map<String, String>>> _fetchOrdonnances() async {
    if (currentUser == null) return [];

    final String patientId = currentUser!.uid;
    List<Map<String, String>> filesData = [];

    try {
      // Étape 1: Récupérer les IDs uniques des médecins avec qui le patient a échangé.
      // C'est une supposition que tout interlocuteur est un médecin.
      // Une meilleure approche serait de vérifier le rôle de chaque utilisateur.
      final Set<String> doctorIds = <String>{};

      // Messages reçus par le patient
      final messagesToPatient = await FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: patientId)
          .get();
      for (var doc in messagesToPatient.docs) {
        doctorIds.add(doc.data()['senderId']);
      }

      // Messages envoyés par le patient
      final messagesFromPatient = await FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: patientId)
          .get();
      for (var doc in messagesFromPatient.docs) {
        doctorIds.add(doc.data()['receiverId']);
      }

      // Étape 2: Pour chaque médecin, lister les ordonnances du patient.
      for (String doctorId in doctorIds) {
        try {
          final ListResult result = await FirebaseStorage.instance
              .ref('ordonnances/$doctorId/$patientId')
              .listAll();

          for (var ref in result.items) {
            final String downloadUrl = await ref.getDownloadURL();
            filesData.add({'name': ref.name, 'url': downloadUrl});
          }
        } catch (e) {
          // Ignore les erreurs pour les médecins qui n'ont pas d'ordonnances pour ce patient.
          print("Aucune ordonnance trouvée pour le médecin $doctorId ou une erreur est survenue: $e");
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération des ordonnances: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des ordonnances: ${e.toString()}')),
        );
      }
    }
    
    // Trier les ordonnances pour afficher les plus récentes en premier
    filesData.sort((a, b) => b['name']!.compareTo(a['name']!));

    return filesData;
  }

  Future<void> _refreshOrdonnances() async {
    if (currentUser != null) {
      setState(() {
        _ordonnancesFuture = _fetchOrdonnances();
      });
    }
  }
  Future<void> _openOrdonnance(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le fichier: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50.withOpacity(0.3), // Arrière-plan subtil
      appBar: AppBar(
        title: Text(
          'Mes Ordonnances',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade600,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: currentUser == null
          ? Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off_outlined, size: 80, color: Colors.blueGrey.shade300),
                    const SizedBox(height: 20),
                    Text(
                      'Accès Restreint',
                      style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Veuillez vous connecter pour consulter vos ordonnances médicales.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(fontSize: 15, color: Colors.blueGrey.shade500),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshOrdonnances,
              color: Colors.blue.shade600,
              child: FutureBuilder<List<Map<String, String>>>(
                future: _ordonnancesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ));
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size: 70),
                            const SizedBox(height: 20),
                            Text(
                              'Oops! Une erreur est survenue',
                              style: GoogleFonts.lato(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Impossible de charger vos ordonnances pour le moment. Veuillez réessayer.\n(${snapshot.error.toString()})',
                              style: GoogleFonts.roboto(color: Colors.black54, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return LayoutBuilder( // Pour que le RefreshIndicator fonctionne sur une liste vide
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.file_copy_outlined, size: 90, color: Colors.blue.shade200),
                                  const SizedBox(height: 24),
                                  Text('Aucune ordonnance trouvée', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
                                  const SizedBox(height: 12),
                                  Text('Vos ordonnances médicales apparaîtront ici dès qu\'elles seront disponibles.', textAlign: TextAlign.center, style: GoogleFonts.roboto(color: Colors.blueGrey.shade600, fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final ordonnances = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: ordonnances.length,
                    itemBuilder: (context, index) {
                      final ordonnance = ordonnances[index];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 16.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(Icons.description_rounded, color: Colors.blue.shade700, size: 24),
                          ),
                          title: Text(
                            ordonnance['name']!,
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.blue.shade400, size: 18),
                          onTap: () => _openOrdonnance(ordonnance['url']!),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}