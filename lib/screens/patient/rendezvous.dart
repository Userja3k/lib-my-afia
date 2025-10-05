import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart'; // Importation de Google Fonts

class RendezvousPage extends StatefulWidget {
  const RendezvousPage({super.key});

  @override
  _RendezvousPageState createState() => _RendezvousPageState();
}

class _RendezvousPageState extends State<RendezvousPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
  }

  // Fonction pour récupérer les rendez-vous de l'utilisateur
  Stream<List<Map<String, dynamic>>> _getRendezvous() {
    if (currentUser != null) {
      return FirebaseFirestore.instance
          .collection('rendezvous')
          .where('userId', isEqualTo: currentUser!.uid)
          .snapshots()
          .map((snapshot) {
        List<Map<String, dynamic>> rendezvous = [];
        for (var doc in snapshot.docs) {
          rendezvous.add({
            'id': doc.id,
            ...doc.data()
          });
        }
        // Trier les rendez-vous par date, les plus récents en premier
        rendezvous.sort((a, b) {
          DateTime timeA = (a['appointmentTime'] as Timestamp).toDate();
          DateTime timeB = (b['appointmentTime'] as Timestamp).toDate();
          return timeB.compareTo(timeA); // Pour un tri décroissant (plus récent en premier)
        });
        return rendezvous;
      });
    } else {
      return Stream.value([]);
    }
  }

  // Affichage de la boîte de dialogue de confirmation
  Future<void> _showDeleteConfirmationDialog(String rendezvousId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 10),
              Text('Confirmer', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Êtes-vous sûr de vouloir annuler ce rendez-vous ?', style: GoogleFonts.roboto()),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Ferme la boîte de dialogue
              },
              child: Text('Non, garder', style: GoogleFonts.roboto(color: Colors.grey.shade700)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever_outlined, size: 18),
              label: Text('Oui, annuler', style: GoogleFonts.roboto()),
              onPressed: () async {
                // Suppression du rendez-vous
                await FirebaseFirestore.instance
                    .collection('rendezvous')
                    .doc(rendezvousId) // Utilisation de l'id du document pour le supprimer
                    .delete();
                Navigator.of(context).pop(); // Ferme la boîte de dialogue
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rendez-vous annulé avec succès.', style: GoogleFonts.roboto()), backgroundColor: Colors.red.shade400),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith( // Pour icônes de statut claires
          statusBarColor: Colors.transparent, // Pour que le dégradé de l'appbar passe derrière
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark, // Pour iOS
        ),
        title: Text('Mes Rendez-vous', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 2.0,
        iconTheme: const IconThemeData(color: Colors.white), // Pour la flèche de retour si besoin
      ),
      body: Container(
        color: Colors.grey[100], // Fond légèrement gris pour contraster avec les cartes
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _getRendezvous(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon( // Icône plus expressive pour l'état vide
                      Icons.event_busy_outlined,
                      size: 80,
                      color: Colors.blueGrey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun rendez-vous',
                      style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vous n\'avez pas encore de rendez-vous planifiés',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.blueGrey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            final rendezvous = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rendezvous.length,
              itemBuilder: (context, index) {
                final rendezvousItem = rendezvous[index];
                final appointmentTimeField = rendezvousItem['appointmentTime'];
                DateTime appointmentTime;
                if (appointmentTimeField != null && appointmentTimeField is Timestamp) {
                  appointmentTime = appointmentTimeField.toDate();
                } else {
                  // Gérer le cas où 'appointmentTime' est null ou n'est pas un Timestamp
                  // Vous pourriez afficher une date par défaut ou un message d'erreur
                  appointmentTime = DateTime.now(); // Exemple de fallback
                }

                final status = rendezvousItem['status'];
                final bool isPastAppointment = appointmentTime.isBefore(DateTime.now()); // Vérifie si le rendez-vous est passé
                // final doctorId = rendezvousItem['doctorId']; // Vous pouvez l'utiliser pour récupérer plus d'infos sur le médecin

                // Déterminer la couleur du statut
                Color statusColor;
                switch (status?.toLowerCase()) {
                  case 'confirmé':
                    statusColor = Colors.green.shade600;
                    break;
                  case 'en attente':
                    statusColor = Colors.orange.shade700;
                    break;
                  case 'annulé':
                    statusColor = Colors.red.shade600;
                    break;
                  default:
                    statusColor = Colors.blueGrey.shade500; // Couleur par défaut ou pour les statuts inconnus
                }

                return Card(
                  elevation: 3, // Ombre subtile
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    // side: BorderSide(color: Colors.blue.shade100, width: 0.5) // Optionnel: bordure subtile
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Icon(
                                    Icons.medical_services_outlined, // Icône plus thématique
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text( // Utilisation de GoogleFonts
                                      'Dr. Médecin', // TODO: Récupérer le vrai nom du médecin si possible
                                      style: GoogleFonts.lato(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15), // Opacité légèrement augmentée
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status ?? 'Non défini',
                                        style: GoogleFonts.roboto(
                                          color: statusColor,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400), // Icône plus douce
                              tooltip: "Annuler le rendez-vous",
                              onPressed: () => _showDeleteConfirmationDialog(rendezvousItem['id']),
                            ),
                          ],
                        ),
                        const Divider(height: 24, thickness: 0.8), // Séparateur plus subtil
                        Row(
                          children: [
                            Icon(
                              Icons.event_note_outlined,
                              // Changer la couleur en rouge si le rendez-vous est passé
                              color: isPastAppointment ? Colors.red.shade700 : Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPastAppointment // Si le rendez-vous est passé
                                  ? 'Passé le ${DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(appointmentTime)}' // Afficher "Passé le..."
                                  : DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(appointmentTime), // Sinon, afficher la date normale
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_filled_outlined,
                              // Changer la couleur en rouge si le rendez-vous est passé
                              color: isPastAppointment ? Colors.red.shade700 : Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPastAppointment // Si le rendez-vous est passé
                                  ? 'À ${DateFormat('HH:mm').format(appointmentTime)}' // Afficher "À HH:mm"
                                  : DateFormat('HH:mm').format(appointmentTime), // Sinon, afficher l'heure normale
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
