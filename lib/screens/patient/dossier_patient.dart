import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class DossierPatientPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const DossierPatientPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  _DossierPatientPageState createState() => _DossierPatientPageState();
}

class _DossierPatientPageState extends State<DossierPatientPage> {
  final _auth = FirebaseAuth.instance;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final List<String> nonOtherInfoEditableKeys = const [
      'first_name', 'last_name', 'name', 'age', 'gender', 'dob', 'bloodGroup', 'blood_type',
      'weight', 'height', 'handicap', 'allergies',
      'phone', 'house_number', 'avenue', 'district', 'city', 'province', 'country',
      'lastSubmitted', 'role', 'email', 'fcmToken', 'medical_notes', 'createdAt', 'prenom', 'nom', 'postnom', 'dateNaissance', 'sexe', 'groupeSanguin', 'antecedentsMedicaux', 'telephone'
    ];

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
    // Initialisation des contrôleurs se fera dans le StreamBuilder pour avoir les données
  }

  void _initializeControllers(Map<String, dynamic> data) {
    // Liste des champs qui seront éditables
    final editableFields = [
      'weight', 'height', 'email', 'telephone', 'country', 'province', 
      'city', 'district', 'avenue', 'house_number', 'antecedentsMedicaux'
    ];

    data.forEach((key, value) {
      if (!nonOtherInfoEditableKeys.contains(key)) {
        editableFields.add(key);
      }
    });

    // Initialiser ou mettre à jour les contrôleurs
    for (var key in editableFields) {
      var textValue = '';
      if (key == 'telephone') {
        textValue = data['telephone']?.toString() ?? data['phone']?.toString() ?? '';
      } else {
        textValue = data[key]?.toString() ?? '';
      }
      if (_controllers.containsKey(key)) {
        _controllers[key]!.text = textValue;
      } else {
        _controllers[key] = TextEditingController(text: textValue);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> updatedData = {};
      _controllers.forEach((key, controller) {
        var value = controller.text;
        // Pour les champs numériques, on essaie de les convertir.
        if (key == 'weight' || key == 'height') {
          updatedData[key] = num.tryParse(value.replaceAll(',', '.')); // Gère la virgule et le point
        } else if (key == 'telephone') {
          updatedData['phone'] = value.trim().isNotEmpty ? value.trim() : null; // Sauvegarder sous la clé 'phone'
        } else {
          // Pour les autres champs, on enregistre la chaîne, ou null si vide.
          updatedData[key] = value.trim().isNotEmpty ? value.trim() : null;
        }
      });

      try {
        await FirebaseFirestore.instance.collection('users').doc(widget.patientId).update(updatedData);
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Modifications enregistrées avec succès.'),
            backgroundColor: theme.colorScheme.primary,
          ));
        }
      } catch (e) {
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur lors de la sauvegarde : $e'),
            backgroundColor: theme.colorScheme.error,
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUserThePatient = _auth.currentUser?.uid == widget.patientId;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Dossier de ${widget.patientName}'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 1.0,
        actions: [
          if (isCurrentUserThePatient)
            IconButton(
              icon: Icon(_isEditing ? Icons.save_alt_outlined : Icons.edit_outlined),
              tooltip: _isEditing ? 'Enregistrer' : 'Modifier',
              onPressed: () {
                if (_isEditing) {
                  _saveChanges();
                }
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
            ),
        ],
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
              return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
            }

            if (snapshot.hasError) {
              return Text(
                'Erreur: ${snapshot.error}', 
                style: TextStyle(color: theme.colorScheme.error)
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text(
                'Aucune donnée de dossier trouvée pour ce patient.', 
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.textTheme.bodyMedium?.color,
                )
              );
            }

            var patientData = snapshot.data!.data() as Map<String, dynamic>;
            if (!_isEditing) {
              _initializeControllers(patientData);
            }

            final int? age = _calculateAge(patientData['dob'] as String?);

            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: Icon(Icons.person_outline, size: 40, color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'ID: ${widget.patientId}',
                      style: TextStyle(
                        fontSize: 16, 
                        color: theme.textTheme.bodyMedium?.color, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                  Divider(height: 30, thickness: 1, color: theme.dividerColor),

                  // --- Informations de santé (prioritaires) ---
                  _buildInfoRow(Icons.cake_outlined, 'Âge', age?.toString() ?? patientData['age']?.toString() ?? 'N/A'),
                  _buildInfoRow(Icons.wc_outlined, 'Sexe', patientData['gender']?.toString() ?? 'N/A'),
                  _buildInfoRow(Icons.bloodtype_outlined, 'Groupe Sanguin', patientData['blood_type']?.toString() ?? 'N/A'),
                  _buildInfoRow(Icons.monitor_weight_outlined, 'Poids', patientData['weight'] != null && patientData['weight'].toString().isNotEmpty ? '${patientData['weight']} kg' : 'non précisé', fieldKey: 'weight', suffix: 'kg'),
                  _buildInfoRow(Icons.height_outlined, 'Taille', patientData['height'] != null && patientData['height'].toString().isNotEmpty ? '${patientData['height']} cm' : 'non précisé', fieldKey: 'height', suffix: 'cm'),
                  if (patientData['handicap'] != null && patientData['handicap'].toString().isNotEmpty)
                    _buildInfoRow(Icons.accessible_outlined, 'Handicap', patientData['handicap'].toString()),
                  if (patientData['allergies'] != null && patientData['allergies'].toString().isNotEmpty)
                    _buildInfoRow(Icons.medical_information_outlined, 'Allergies', patientData['allergies'].toString()),
                  _buildInfoRow(Icons.history_edu_outlined, 'Antécédents', patientData['antecedentsMedicaux']?.toString() ?? 'N/A', fieldKey: 'antecedentsMedicaux'),

                  // --- Informations de Contact ---
                  const SizedBox(height: 20),
                  Text(
                    "Contact", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18, 
                      color: theme.colorScheme.primary
                    )
                  ),
                  Divider(height: 20, color: theme.dividerColor),
                  _buildInfoRow(Icons.email_outlined, 'Email', patientData['email']?.toString() ?? 'N/A', fieldKey: 'email'),
                  _buildInfoRow(Icons.phone_outlined, 'Téléphone', patientData['telephone']?.toString() ?? patientData['phone']?.toString() ?? 'N/A', fieldKey: 'telephone'),

                  // --- Informations d'Adresse ---
                  const SizedBox(height: 20),
                  Text(
                    "Adresse", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18, 
                      color: theme.colorScheme.primary
                    )
                  ),
                  Divider(height: 20, color: theme.dividerColor),
                  _buildInfoRow(Icons.flag_outlined, 'Pays', patientData['country']?.toString() ?? 'N/A', fieldKey: 'country'),
                  _buildInfoRow(Icons.location_city_sharp, 'Province', patientData['province']?.toString() ?? 'N/A', fieldKey: 'province'),
                  _buildInfoRow(Icons.location_on_outlined, 'Ville', patientData['city']?.toString() ?? 'N/A', fieldKey: 'city'),
                  _buildInfoRow(Icons.home_work_outlined, 'Commune/Quartier', patientData['district']?.toString() ?? 'N/A', fieldKey: 'district'),
                  _buildInfoRow(Icons.signpost_outlined, 'Avenue', patientData['avenue']?.toString() ?? 'N/A', fieldKey: 'avenue'),
                  _buildInfoRow(Icons.onetwothree_outlined, 'Numéro', patientData['house_number']?.toString() ?? 'N/A', fieldKey: 'house_number'),

                  // --- Autres Informations ---
                  const SizedBox(height: 20),
                  Text(
                    "Autres Informations", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18, 
                      color: theme.colorScheme.primary
                    )
                  ),
                  Divider(height: 20, color: theme.dividerColor),
                  ...patientData.entries
                      .where((entry) => !nonOtherInfoEditableKeys.contains(entry.key))
                      .map((entry) {
                    return _buildInfoRow(
                      Icons.info_outline,
                      entry.key.replaceAll('_', ' ').capitalizeFirst(),
                      entry.value.toString(),
                      fieldKey: entry.key,
                    );
                  }),

                  if (patientData.containsKey('medical_notes') && patientData['medical_notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Text(
                      "Notes Médicales:", 
                      style: TextStyle(
                        fontWeight: FontWeight.w600, 
                        fontSize: 16,
                        color: theme.textTheme.titleMedium?.color,
                      )
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        patientData['medical_notes'].toString(), 
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        )
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {String? fieldKey, String? suffix}) {
    final bool isEditable = _isEditing && fieldKey != null && _controllers.containsKey(fieldKey);
    final theme = Theme.of(context);

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: theme.iconTheme.color),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Text(
                '$label: ', 
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.w600, 
                  fontSize: 15,
                  color: theme.textTheme.titleMedium?.color,
                )
              ),
            ),
            Expanded(
              child: isEditable
                  ? TextFormField(
                      controller: _controllers[fieldKey],
                      decoration: InputDecoration(
                        suffixText: suffix,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                        ),
                      ),
                      keyboardType: (fieldKey == 'weight' || fieldKey == 'height')
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : (fieldKey == 'telephone')
                              ? TextInputType.phone
                              : (fieldKey == 'email')
                                ? TextInputType.emailAddress
                                : TextInputType.text,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      validator: (val) {
                        if (fieldKey == 'weight' || fieldKey == 'height') {
                          if (val != null && val.isNotEmpty && num.tryParse(val) == null) {
                            return 'Veuillez entrer un nombre valide.';
                          }
                        }
                        return null;
                      },
                    )
                  : Text(
                      value,
                      style: GoogleFonts.roboto(
                        fontSize: 15, 
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
            ),
          ],
        ),
      );
  }
}

extension StringExtension on String {
    String capitalizeFirst() {
      if (isEmpty) return "";
      return "${this[0].toUpperCase()}${substring(1)}";
    }
}