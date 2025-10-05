import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importation de FirebaseAuth
import 'package:google_fonts/google_fonts.dart'; // Importation de Google Fonts

class AppointmentPage extends StatefulWidget {
  final String? doctorId; // ID optionnel du médecin
  final String? doctorName; // Nom optionnel du médecin
  final bool isDesktop; // Nouveau paramètre pour le mode desktop

  const AppointmentPage({
    super.key, 
    this.doctorId, 
    this.doctorName,
    this.isDesktop = false,
  });

  @override
  _AppointmentPageState createState() => _AppointmentPageState();
}
class _AppointmentPageState extends State<AppointmentPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<DateTime> _bookedSlots = [];
  // Stores full DateTime of booked appointments
  String? _doctorSpecialty;
  bool _isLoadingSpecialty = false;
  bool _isDateSaturated = false;

  @override
  void initState() {
    super.initState();
    // Utiliser _effectiveDoctorId pour récupérer la spécialité du médecin assigné (spécifique ou par défaut)
    String doctorIdForSpecialty = _effectiveDoctorId;
    if (doctorIdForSpecialty.isNotEmpty) {
      _fetchDoctorSpecialty(doctorIdForSpecialty);
    }
  }

  String get _effectiveDoctorId => widget.doctorId ?? 'TRITRiB31OgsMxFceg91hIAfjLW2'; // Fallback ID

  Future<void> _fetchBookedSlots(DateTime date) async {
    final String doctorId = _effectiveDoctorId;
    final DateTime startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rendezvous')
          .where('doctorId', isEqualTo: doctorId)
          .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('appointmentTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      if (mounted) {
        setState(() {
          _bookedSlots = snapshot.docs.map((doc) {
            final data = doc.data();
            // Ensure 'appointmentTime' exists and is a Timestamp
            if (data.containsKey('appointmentTime') && data['appointmentTime'] is Timestamp) {
              return (data['appointmentTime'] as Timestamp).toDate();
            }
            // Return a placeholder or handle error if data is not as expected
            // For simplicity, filtering out invalid entries here
            return null; 
          }).whereType<DateTime>().toList(); // Filter out nulls and ensure correct type
          _checkDateSaturation();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la récupération des créneaux: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _fetchDoctorSpecialty(String doctorId) async {
    if (doctorId.isEmpty) return;
    if (mounted) {
      setState(() {
        _isLoadingSpecialty = true;
      });
    }
    try {
      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance.collection('doctors').doc(doctorId).get();
      if (doctorDoc.exists && mounted) {
        final data = doctorDoc.data() as Map<String, dynamic>?;
        setState(() {
          _doctorSpecialty = data?.containsKey('specialty') == true ? data!['specialty'] as String? : null;
          _isLoadingSpecialty = false;
        });
      } else if (mounted) {
        setState(() {
          _doctorSpecialty = null; // Spécialité non trouvée
          _isLoadingSpecialty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _doctorSpecialty = null; // Erreur de chargement
          _isLoadingSpecialty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des informations du médecin: ${e.toString()}')),
        );
      }
    }
  }
  // Fonction pour afficher le sélecteur de date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime currentDate = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? currentDate,
      firstDate: currentDate, // Pas de sélection de dates passées
      lastDate: DateTime(currentDate.year + 1), // Limite sur un an
      helpText: 'SÉLECTIONNER UNE DATE',
      cancelText: 'ANNULER',
      confirmText: 'OK',
      builder: (context, child) {
        return Theme(data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: Colors.blue.shade700)), child: child!);
        },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      if (mounted) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = null; // Reset time when date changes
          _isDateSaturated = false; // Reset saturation status
          _bookedSlots.clear(); // Clear previously fetched slots
        });
        // Fetch new slots for the newly selected date
        await _fetchBookedSlots(pickedDate);
      }
    }
  }

  // Fonction pour afficher le sélecteur d'heure
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay currentTime = TimeOfDay.now();
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? currentTime,
      helpText: 'SÉLECTIONNER UNE HEURE',
      cancelText: 'ANNULER',
      confirmText: 'OK',
      builder: (context, child) {
        return Theme(data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: Colors.blue.shade700)), child: child!);
        },
    );

    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = null; // Temporarily set to null, will be updated after validation
      });
      _validateAndSetTime(pickedTime);
    }
  }

  void _validateAndSetTime(TimeOfDay timeToValidate) {
    if (_selectedDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez d\'abord sélectionner une date.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    // Validate business hours (8 AM to 4 PM, so 8:00 to 15:59)
    if (timeToValidate.hour < 8 || timeToValidate.hour >= 16) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Les rendez-vous sont possibles uniquement de 8h00 à 15h59.'), backgroundColor: Colors.red),
        );
      }
      // _selectedTime remains null or its previous valid value
      return;
    }

    // Validate against booked slots
    final proposedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      timeToValidate.hour,
      timeToValidate.minute,
    );

    bool isSlotTaken = _bookedSlots.any((bookedTime) =>
        bookedTime.year == proposedDateTime.year &&
        bookedTime.month == proposedDateTime.month &&
        bookedTime.day == proposedDateTime.day &&
        bookedTime.hour == proposedDateTime.hour &&
        bookedTime.minute == proposedDateTime.minute);

    if (isSlotTaken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce créneau horaire est déjà réservé.'), backgroundColor: Colors.red),
        );
      }
      // _selectedTime remains null or its previous valid value
      return;
    }

    // If all validations pass
    if (mounted) {
      setState(() {
        _selectedTime = timeToValidate;
      });
    }
  }

  Future<void> _bookAppointmentInFirestore(String userId, DateTime appointmentDateTime, String doctorId) async {
    try {
      await FirebaseFirestore.instance.collection('rendezvous').add({
        'userId': userId,
        'doctorId': doctorId,
        'appointmentTime': appointmentDateTime,
        'status': 'confirmé', // Statut direct, plus de paiement en attente
        'timestamp': FieldValue.serverTimestamp(), // Add timestamp
        'doctorSpecialty': _doctorSpecialty ?? 'Généraliste', // Ajout de la spécialité du médecin
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rendez-vous pris avec succès !'), backgroundColor: Colors.green),
        );
        // Optionnellement, effacez les selections ou naviguez ailleurs ici:
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
        });
      }
    } catch (e) {
      print("Erreur lors de la création du rendez-vous: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la demande de rendez-vous: ${e.toString()}')),
        );
      }
    }
  }

  // Fonction pour initier le processus de paiement et de prise de rendez-vous
  Future<void> _submitAppointment() async {
    if (_selectedDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner une date et une heure'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    if (_selectedTime == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner une heure valide.'), backgroundColor: Colors.orange),
        );
      }
      // Attempt to re-validate or guide user
      _validateAndSetTime(TimeOfDay.now()); // Example: try validating current time, or just return
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur non authentifié pour continuer.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Vérification du délai de 24h depuis le dernier rendez-vous pris
    try {
      final lastAppointmentQuery = await FirebaseFirestore.instance
          .collection('rendezvous')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true) // Le plus récent en premier
          .limit(1)
          .get();

      if (lastAppointmentQuery.docs.isNotEmpty) {
        final lastAppointmentData = lastAppointmentQuery.docs.first.data();
        if (lastAppointmentData.containsKey('timestamp') && lastAppointmentData['timestamp'] is Timestamp) {
          final DateTime lastAppointmentTime = (lastAppointmentData['timestamp'] as Timestamp).toDate();
          if (DateTime.now().difference(lastAppointmentTime).inHours < 24) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vous devez attendre 24 heures après votre dernier rendez-vous pris avant d\'en demander un nouveau.'), backgroundColor: Colors.blueAccent),
              );
            }
            return; // Arrêter la soumission
          }
        }
      }
    } catch (e) {
      // Gérer l'erreur de vérification du délai si nécessaire, mais ne pas bloquer la soumission pour cela
      // sauf si c'est une politique stricte. Pour l'instant, on logue l'erreur.
      print("Erreur lors de la vérification du délai du dernier rendez-vous: $e");
      // Optionnel: afficher un message à l'utilisateur si cette vérification échoue.
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Impossible de vérifier le délai depuis votre dernier rendez-vous. Erreur: ${e.toString()}'), backgroundColor: Colors.orangeAccent),
      //   );
      // }
      // return; // Décommentez pour bloquer si la vérification échoue
    }

    // Attendre si la spécialité du médecin est en cours de chargement
    if (_isLoadingSpecialty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez patienter, les informations du médecin sont en cours de chargement...'), backgroundColor: Colors.blueAccent),
        );
      }
      return;
    }

    // Avertissement si un doctorId spécifique est fourni mais que sa spécialité n'a pas pu être chargée.
    // Dans ce cas, la vérification de doublon de spécialité pour le jour ne sera pas effectuée.
    if (widget.doctorId != null && (_doctorSpecialty == null || _doctorSpecialty!.isEmpty)) {
        // Optionnel: Afficher un message à l'utilisateur et empêcher la soumission.
        // if (mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(content: Text('Impossible de vérifier les conflits de rendez-vous car la spécialité du médecin est inconnue.'), backgroundColor: Colors.orange),
        //   );
        // }
        // return;
    }

    // Vérification pour un rendez-vous existant dans la même spécialité le même jour (non annulé)
    // MODIFICATION: Vérification pour n'importe quel rendez-vous le même jour, peu importe la spécialité.
    // if (_doctorSpecialty != null && _doctorSpecialty!.isNotEmpty) { // Ancienne condition
      final DateTime startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0);
      final DateTime endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59, 999);
      try {
        final existingAppointmentsSnapshot = await FirebaseFirestore.instance
            .collection('rendezvous')
            .where('userId', isEqualTo: user.uid)
            // .where('doctorSpecialty', isEqualTo: _doctorSpecialty) // Supprimé pour vérifier tous les RDV du jour
            .where('appointmentTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('appointmentTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .where('status', isNotEqualTo: 'annulé') // Exclure les rendez-vous déjà annulés
            .limit(1) // On a juste besoin de savoir s'il en existe au moins un
            .get();
        if (existingAppointmentsSnapshot.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vous avez déjà un rendez-vous actif prévu pour ce jour-là.'), backgroundColor: Colors.orange),
            );
          }
          return; // Arrêter la soumission
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impossible de vérifier les conflits de rendez-vous pour le moment. Erreur: ${e.toString()}'), backgroundColor: Colors.redAccent),
          );
        }
        return; // Arrêter la soumission en cas d'erreur
      }
    // } // Fin de l'ancienne condition

    // Final validation of time before proceeding
    if (_selectedTime!.hour < 8 || _selectedTime!.hour >= 16) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Heure de rendez-vous invalide (8h-16h).'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final DateTime appointmentDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    bool isSlotTaken = _bookedSlots.any((bookedTime) =>
        bookedTime.year == appointmentDateTime.year &&
        bookedTime.month == appointmentDateTime.month &&
        bookedTime.day == appointmentDateTime.day &&
        bookedTime.hour == appointmentDateTime.hour &&
        bookedTime.minute == appointmentDateTime.minute);

    if (isSlotTaken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce créneau a été réservé. Veuillez choisir une autre heure.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Déterminer le doctorId et doctorName à utiliser
    String finalDoctorId = _effectiveDoctorId;
    // String finalDoctorNameForPayment = widget.doctorName ?? 'Médecin Généraliste'; // N'est plus nécessaire pour le paiement

    await _bookAppointmentInFirestore(user.uid, appointmentDateTime, finalDoctorId);

  }

  void _checkDateSaturation() {
    if (_selectedDate == null) {
      _isDateSaturated = false;
      return;
    }

    const int businessStartHour = 8;
    const int businessEndHour = 16; // up to 15:xx
    int totalPotentialHourlySlots = businessEndHour - businessStartHour; // 8, 9, ..., 15 (8 slots)

    Set<int> distinctBookedHoursInBusinessTime = {};
    for (DateTime bookedTime in _bookedSlots) {
      if (bookedTime.hour >= businessStartHour && bookedTime.hour < businessEndHour) {
        distinctBookedHoursInBusinessTime.add(bookedTime.hour);
      }
    }
    if (mounted) {
       setState(() {
        _isDateSaturated = distinctBookedHoursInBusinessTime.length >= totalPotentialHourlySlots;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          'Demander un Rendez-vous',
          style: GoogleFonts.lato(
            color: Colors.white, 
            fontWeight: FontWeight.bold, 
            fontSize: widget.isDesktop ? 24 : 20,
          ),
        ),
        centerTitle: widget.isDesktop,
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
      body: widget.isDesktop 
        ? _buildDesktopLayout(isDarkMode)
        : _buildMobileLayout(isDarkMode),
    );
  }

  Widget _buildDesktopLayout(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode 
            ? [Colors.grey.shade900, Colors.grey.shade800]
            : [Colors.grey.shade50, Colors.white],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Card(
              elevation: 12,
              shadowColor: Colors.black.withOpacity(0.2),
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête de la card
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade600, Colors.blue.shade400],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.calendar_today_outlined,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Prendre un Rendez-vous',
                            style: GoogleFonts.lato(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sélectionnez une date et une heure pour votre consultation',
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Informations du médecin
                    _buildDoctorInfoCard(isDarkMode, true),
                    const SizedBox(height: 32),
                    
                    // Sélecteurs de date et heure
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTimePickerCard(
                            title: 'Choisir une date',
                            value: _selectedDate == null
                                ? 'Aucune date sélectionnée'
                                : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                            icon: Icons.calendar_today_outlined,
                            isSaturated: _isDateSaturated,
                            onPressed: () => _selectDate(context),
                            isDarkMode: isDarkMode,
                            isDesktop: true,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildDateTimePickerCard(
                            title: 'Choisir une heure',
                            value: _selectedTime == null
                                ? 'Aucune heure sélectionnée'
                                : _selectedTime!.format(context),
                            icon: Icons.access_time_outlined,
                            isSaturated: false,
                            onPressed: () => _selectTime(context),
                            isDarkMode: isDarkMode,
                            isDesktop: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    
                    // Bouton de confirmation
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.check_circle_outline_rounded, 
                          color: Colors.white, 
                          size: 24,
                        ),
                        label: Text(
                          'Confirmer le Rendez-vous', 
                          style: GoogleFonts.roboto(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _submitAppointment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête mobile
          Center(
            child: Column(
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
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Prendre un Rendez-vous',
                  style: GoogleFonts.lato(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sélectionnez une date et une heure pour votre consultation',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Informations du médecin
          _buildDoctorInfoCard(isDarkMode, false),
          const SizedBox(height: 20),
          
          // Sélecteurs de date et heure
          _buildDateTimePickerCard(
            title: 'Choisir une date',
            value: _selectedDate == null
                ? 'Aucune date sélectionnée'
                : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
            icon: Icons.calendar_today_outlined,
            isSaturated: _isDateSaturated,
            onPressed: () => _selectDate(context),
            isDarkMode: isDarkMode,
            isDesktop: false,
          ),
          const SizedBox(height: 20),
          _buildDateTimePickerCard(
            title: 'Choisir une heure',
            value: _selectedTime == null
                ? 'Aucune heure sélectionnée'
                : _selectedTime!.format(context),
            icon: Icons.access_time_outlined,
            isSaturated: false,
            onPressed: () => _selectTime(context),
            isDarkMode: isDarkMode,
            isDesktop: false,
          ),
          const SizedBox(height: 40),
          
          // Bouton de confirmation
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            label: Text(
              'Confirmer le Rendez-vous', 
              style: GoogleFonts.roboto(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            onPressed: _submitAppointment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorInfoCard(bool isDarkMode, bool isDesktop) {
    return isDesktop 
      ? Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.blue.shade900 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medical_services_outlined, 
                    color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700, 
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoadingSpecialty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 24, 
                              height: 24, 
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        )
                      else if (_doctorSpecialty != null && _doctorSpecialty!.isNotEmpty) ...[
                        Text(
                          "Spécialité du Médecin :",
                          style: GoogleFonts.lato(
                            fontSize: 16, 
                            color: isDarkMode ? Colors.grey.shade300 : Colors.blueGrey.shade600, 
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _doctorSpecialty!,
                          style: GoogleFonts.lato(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold, 
                            color: isDarkMode ? Colors.white : Colors.blue.shade800,
                          ),
                        ),
                      ] else ...[
                        Text(
                          widget.doctorId != null ? "ID du Médecin :" : "Médecin :",
                          style: GoogleFonts.lato(
                            fontSize: 16, 
                            color: isDarkMode ? Colors.grey.shade300 : Colors.blueGrey.shade600, 
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.doctorId != null ? widget.doctorId! : (widget.doctorName ?? "Médecin Généraliste"),
                          style: GoogleFonts.lato(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold, 
                            color: isDarkMode ? Colors.white : Colors.blue.shade800,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
      : Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade800 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.blue.shade900 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.medical_services_outlined, 
                  color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700, 
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoadingSpecialty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                      )
                    else if (_doctorSpecialty != null && _doctorSpecialty!.isNotEmpty) ...[
                      Text(
                        "Spécialité du Médecin :",
                        style: GoogleFonts.lato(
                          fontSize: 14, 
                          color: isDarkMode ? Colors.grey.shade300 : Colors.blueGrey.shade600, 
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _doctorSpecialty!,
                        style: GoogleFonts.lato(
                          fontSize: 17, 
                          fontWeight: FontWeight.bold, 
                          color: isDarkMode ? Colors.white : Colors.blue.shade800,
                        ),
                      ),
                    ] else ...[
                      Text(
                        widget.doctorId != null ? "ID du Médecin :" : "Médecin :",
                        style: GoogleFonts.lato(
                          fontSize: 14, 
                          color: isDarkMode ? Colors.grey.shade300 : Colors.blueGrey.shade600, 
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.doctorId != null ? widget.doctorId! : (widget.doctorName ?? "Médecin Généraliste"),
                        style: GoogleFonts.lato(
                          fontSize: 17, 
                          fontWeight: FontWeight.bold, 
                          color: isDarkMode ? Colors.white : Colors.blue.shade800,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildDateTimePickerCard({
    required String title,
    required String value,
    required IconData icon,
    required bool isSaturated,
    required VoidCallback onPressed,
    required bool isDarkMode,
    required bool isDesktop,
  }) {
    return isDesktop 
      ? Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0, 
                vertical: 24.0,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.blue.shade900 : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon, 
                      color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700, 
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title, 
                          style: GoogleFonts.lato(
                            fontSize: 18, 
                            fontWeight: FontWeight.w600, 
                            color: isDarkMode ? Colors.white : Colors.blueGrey.shade800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 16,
                            color: isSaturated 
                              ? Colors.red.shade400 
                              : (isDarkMode ? Colors.grey.shade300 : Colors.blueGrey.shade600),
                            fontWeight: isSaturated ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isSaturated && title == 'Choisir une date')
                          const Padding(
                            padding: EdgeInsets.only(top: 6.0),
                            child: Text(
                              'Tous les créneaux sont pris pour ce jour.', 
                              style: TextStyle(
                                fontSize: 13, 
                                color: Colors.red, 
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded, 
                    color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700, 
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        )
      : InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0, 
              vertical: 18.0,
            ),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.blue.shade900 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon, 
                    color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700, 
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: GoogleFonts.lato(
                          fontSize: 17, 
                          fontWeight: FontWeight.w600, 
                          color: isDarkMode ? Colors.white : Colors.blueGrey.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          color: isSaturated 
                            ? Colors.red.shade400 
                            : (isDarkMode ? Colors.grey.shade300 : Colors.blueGrey.shade600),
                          fontWeight: isSaturated ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isSaturated && title == 'Choisir une date')
                        const Padding(
                          padding: EdgeInsets.only(top: 6.0),
                          child: Text(
                            'Tous les créneaux sont pris pour ce jour.', 
                            style: TextStyle(
                              fontSize: 12.5, 
                              color: Colors.red, 
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded, 
                  color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700, 
                  size: 18,
                ),
              ],
            ),
          ),
        );
  }
}
