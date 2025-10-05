import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_sound/flutter_sound.dart' as ap;
import 'package:hospital_virtuel/screens/patient/full_screen_image_page.dart';

class DossierMedicalPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const DossierMedicalPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  _DossierMedicalPageState createState() => _DossierMedicalPageState();
}

class _DossierMedicalPageState extends State<DossierMedicalPage> {
  // Audio Player State
  final ap.FlutterSoundPlayer _audioPlayer = ap.FlutterSoundPlayer();
  bool _isAudioPlaying = false;
  String? _currentlyPlayingAudioUrl;
  String? _currentlyPlayingAudioUrlForProgress;
  Duration? _audioDuration;
  Duration? _audioPosition;

  // Fonction pour calculer l'âge à partir de la date de naissance
  int? _calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty) {
      return null;
    }
    try {
      // Accepte les formats 'd/M/yyyy' et 'dd/MM/yyyy'
      final DateFormat format = DateFormat('d/M/yyyy');
      final DateTime birthDate = format.parse(dobString);
      final DateTime today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      print('Erreur lors de l\'analyse de la date de naissance : $e');
      return null;
    }
  }
  @override
  void initState() {
    super.initState();
    // Temporairement désactivé - à adapter pour flutter_sound
    // _audioPlayer.onDurationChanged.listen((Duration d) {
    //   if (mounted && _currentlyPlayingAudioUrlForProgress != null && _currentlyPlayingAudioUrlForProgress == _currentlyPlayingAudioUrl) {
    //     setState(() => _audioDuration = d);
    //   }
    // });

    // _audioPlayer.onPositionChanged.listen((Duration p) {
    //   if (mounted && _currentlyPlayingAudioUrlForProgress != null && _currentlyPlayingAudioUrlForProgress == _currentlyPlayingAudioUrl) {
    //     setState(() => _audioPosition = p);
    //   }
    // });

    // Initialiser le player audio
    // _audioPlayer.openPlayer().then((value) {
    //   // Player is ready
    // });

    // Avec flutter_sound, nous utilisons onPlayerComplete pour détecter la fin
    // _audioPlayer.onPlayerComplete.listen((event) {
    //   if (mounted) {
    //     setState(() {
    //       _isAudioPlaying = false;
    //       _audioPosition = _audioDuration;
    //       _currentlyPlayingAudioUrl = null;
    //       _audioPosition = Duration.zero;
    //       _audioDuration = null;
    //     });
    //   }
    // });
  }

  @override
  void dispose() {
    _audioPlayer.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("[DossierMedicalPage] build: patientId = ${widget.patientId}"); // Débogage
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          'Dossier médical',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20, // Taille ajustée pour les noms longs
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
        iconTheme: const IconThemeData(color: Colors.white), // Pour la flèche de retour
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.patientId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Erreur: ${snapshot.error}', style: TextStyle(color: Colors.red));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text('Aucune donnée de dossier trouvée pour ce patient.', style: TextStyle(fontStyle: FontStyle.italic));
            }

            var patientData = snapshot.data!.data() as Map<String, dynamic>;
            final int? age = _calculateAge(patientData['dob'] as String?);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).primaryColorLight,
                    child: Icon(Icons.person_outline, size: 40, color: Theme.of(context).primaryColor),
                  ),
                ),
                SizedBox(height: 16),
                Center(
                  child: Text(
                    'ID: ${widget.patientId}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.bold),
                  ),
                ),
                Divider(height: 30, thickness: 1),

                // --- Informations de santé (prioritaires) ---
                _buildInfoRow(Icons.cake_outlined, 'Âge', age?.toString() ?? patientData['age']?.toString() ?? 'N/A'),
                _buildInfoRow(Icons.wc_outlined, 'Sexe', patientData['gender']?.toString() ?? 'N/A'),
                _buildInfoRow(Icons.bloodtype_outlined, 'Groupe Sanguin', patientData['blood_type']?.toString() ?? 'N/A'),
                _buildInfoRow(Icons.monitor_weight_outlined, 'Poids', patientData['weight'] != null && patientData['weight'].toString().isNotEmpty ? '${patientData['weight']} kg' : 'non précisé'),
                _buildInfoRow(Icons.height_outlined, 'Taille', patientData['height'] != null && patientData['height'].toString().isNotEmpty ? '${patientData['height']} cm' : 'non précisé'),
                if (patientData['handicap'] != null && patientData['handicap'].toString().isNotEmpty)
                  _buildInfoRow(Icons.accessible_outlined, 'Handicap', patientData['handicap'].toString()),
                if (patientData['allergies'] != null && patientData['allergies'].toString().isNotEmpty)
                  _buildInfoRow(Icons.medical_information_outlined, 'Allergies', patientData['allergies'].toString()),

                // --- Autres Informations ---
                SizedBox(height: 10),
                Text("Autres Informations:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                SizedBox(height: 5),
                ...patientData.entries
                    .where((entry) => ![
                          'first_name', 'last_name', 'name', 'age', 'gender', 'dob', 'bloodGroup', 'blood type', 'blood_type', // Informations de base
                          'weight', 'height', 'handicap', 'allergies', // Informations de santé
                          'phone', 'house_number', // Informations personnelles (masquées ou déplacées)
                          'lastSubmitted', 'role', 'email', 'fcmToken', 'medical_notes', // Champs système ou notes (lastSubmitted est géré au-dessus)
                        ].contains(entry.key))
                    .map((entry) {
                  return _buildInfoRow(Icons.info_outline, entry.key.replaceAll('_', ' ').capitalizeFirst(), entry.value.toString());
                }),

                if (patientData.containsKey('medical_notes') && patientData['medical_notes'].toString().isNotEmpty) ...[
                  SizedBox(height: 15),
                  Text("Notes Médicales:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  SizedBox(height: 5),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(patientData['medical_notes'].toString(), style: TextStyle(fontSize: 14)),
                  ),
                ],

                Divider(height: 40, thickness: 1),
                Text(
                  "Historique des Soumissions",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark),
                ),
                SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('feelings')
                      .where('patientId', isEqualTo: widget.patientId) // CORRECTION: Le champ est 'patientId', pas 'userId'
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, feelingsSnapshot) {
                    if (feelingsSnapshot.connectionState == ConnectionState.waiting) {
                      print("[DossierMedicalPage] feelings stream: en attente de données...");
                      return Center(child: CircularProgressIndicator());
                    }
                    if (feelingsSnapshot.hasError) {
                      print("[DossierMedicalPage] feelings stream ERREUR: ${feelingsSnapshot.error}");
                      return Text('Erreur: ${feelingsSnapshot.error}', style: TextStyle(color: Colors.red));
                    }
                    if (!feelingsSnapshot.hasData || feelingsSnapshot.data!.docs.isEmpty) {
                      print("[DossierMedicalPage] feelings stream: Aucun document trouvé pour patientId ${widget.patientId}");
                      return Text("Aucun symptôme soumis par ce patient.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700]));
                    }

                    final allDocs = feelingsSnapshot.data!.docs;
                    print("[DossierMedicalPage] feelings stream: ${allDocs.length} documents trouvés.");
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: allDocs.length,
                      itemBuilder: (context, index) {
                        var feelingData = allDocs[index].data() as Map<String, dynamic>;
                        var feelingDocId = allDocs[index].id;

                        List<dynamic>? symptomsList = feelingData['selectedSymptoms'] as List<dynamic>?;
                        String symptomsText = symptomsList?.join(', ') ?? 'Non spécifiés';
                        List<dynamic>? imageUrls = feelingData['imageUrls'] as List<dynamic>?;

                        return Card(
                          elevation: 2,
                          margin: EdgeInsets.symmetric(vertical: 8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (feelingData['consultationFor'] == 'other')
                                  ..._buildOtherPatientDetails(feelingData),
                                _buildInfoRow(Icons.thermostat_outlined, "Symptômes", symptomsText),
                                if (feelingData['message'] != null && feelingData['message'].toString().isNotEmpty)
                                  _buildInfoRow(Icons.message_outlined, "Message", feelingData['message'].toString()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Images jointes:", style: TextStyle(fontWeight: FontWeight.w500)),
                                        SizedBox(height: 4),
                                        if (imageUrls != null && imageUrls.isNotEmpty)
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: imageUrls.map<Widget>((url) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(right: 8.0),
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => FullScreenImagePage(
                                                            imageProvider: NetworkImage(url.toString()),
                                                            tag: url.toString(),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: Hero(
                                                      tag: url.toString(),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(8.0),
                                                        child: Image.network(url.toString(), height: 100, width: 100, fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) => Container(height: 100, width: 100, color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey)),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          )
                                        else
                                          Text("Aucune image jointe à la consultation", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                if (feelingData['audioPath'] != null)
                                  _buildAudioPlayerWidget(feelingData['audioPath'], "Message vocal", feelingDocId, false),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAudioPlayerWidget(String audioUrl, String fileName, String messageId, bool isMe) {
    bool isCurrentlyPlayingThisSpecificAudio = _currentlyPlayingAudioUrl == audioUrl;
    bool isPlaying = isCurrentlyPlayingThisSpecificAudio && _isAudioPlaying;

    Color iconColor = Colors.blue;
    Color textColor = Colors.black87;
    Color progressColor = Colors.blue.withOpacity(0.7);
    Color thumbColor = Colors.blue;

    Duration? currentPosition = isCurrentlyPlayingThisSpecificAudio ? _audioPosition : Duration.zero;
    Duration? totalDuration = isCurrentlyPlayingThisSpecificAudio ? _audioDuration : null;

    String formatDuration(Duration? d) {
      if (d == null) return "--:--";
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
      String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
      if (d.inHours > 0) {
        return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
      }
      return "$twoDigitMinutes:$twoDigitSeconds";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle_filled_outlined : Icons.play_circle_fill_outlined, color: iconColor, size: 32),
            onPressed: () async {
              if (isPlaying) {
                // Temporairement désactivé - à adapter pour flutter_sound
                // await _audioPlayer.pause();
              } else {
                if (_isAudioPlaying && _currentlyPlayingAudioUrl != audioUrl) {
                  // Temporairement désactivé - à adapter pour flutter_sound
                  // await _audioPlayer.stop();
                }
                setState(() {
                  _audioDuration = null;
                  _audioPosition = Duration.zero;
                  _currentlyPlayingAudioUrlForProgress = audioUrl;
                  _currentlyPlayingAudioUrl = audioUrl;
                });
                await _audioPlayer.startPlayer(fromURI: audioUrl);
              }
            },
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.0,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 14.0),
                    thumbColor: (isCurrentlyPlayingThisSpecificAudio && totalDuration != null && totalDuration.inMilliseconds > 0) ? thumbColor : Colors.transparent,
                    overlayColor: (isCurrentlyPlayingThisSpecificAudio && totalDuration != null && totalDuration.inMilliseconds > 0) ? thumbColor.withOpacity(0.3) : Colors.transparent,
                    activeTrackColor: (isCurrentlyPlayingThisSpecificAudio && totalDuration != null && totalDuration.inMilliseconds > 0) ? progressColor : progressColor.withOpacity(0.3),
                    inactiveTrackColor: (isCurrentlyPlayingThisSpecificAudio && totalDuration != null && totalDuration.inMilliseconds > 0) ? progressColor.withOpacity(0.3) : progressColor.withOpacity(0.1),
                  ),
                  child: Slider(
                    min: 0.0,
                    max: (totalDuration != null && totalDuration.inMilliseconds > 0) ? totalDuration.inMilliseconds.toDouble() : 1.0,
                    value: (currentPosition?.inMilliseconds.toDouble() ?? 0.0)
                        .clamp(0.0, (totalDuration?.inMilliseconds.toDouble() ?? 1.0)),
                    onChanged: (isCurrentlyPlayingThisSpecificAudio && totalDuration != null && totalDuration.inMilliseconds > 0) ? (value) {
                       final newPosition = Duration(milliseconds: value.toInt());
                       // Temporairement désactivé - à adapter pour flutter_sound
                       // _audioPlayer.seek(newPosition);
                       setState(() => _audioPosition = newPosition);
                    } : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0).copyWith(top:0.0, bottom: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(currentPosition), style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
                      Text(formatDuration(totalDuration), style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _buildOtherPatientDetails(Map<String, dynamic> feelingData) {
  List<Widget> widgets = [];
  widgets.add(Text("Consultation pour: Autre personne", style: TextStyle(fontWeight: FontWeight.w500)));
  widgets.add(const SizedBox(height: 8));

  feelingData.entries
      .where((entry) => entry.key.startsWith('otherPatient'))
      .forEach((entry) {
        String label = entry.key
            .replaceFirst('otherPatient', '')
            .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (Match m) => ' ${m.group(0)}')
            .capitalizeFirst();
        if (entry.value != null && entry.value.toString().trim().isNotEmpty) {
           widgets.add(_buildInfoRow(Icons.person_search_outlined, label, entry.value.toString()));
        }
      });
   return widgets;
}

Widget _buildInfoRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        Expanded(child: Text(value, style: TextStyle(fontSize: 14))),
      ],
    ),
  );
}

extension StringExtension on String {
    String capitalizeFirst() {
      if (isEmpty) return "";
      return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
    }
}