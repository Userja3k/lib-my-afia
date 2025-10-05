import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RappelMedicamentPage extends StatefulWidget {
  final String? patientId;
  final String? patientName;
  
  const RappelMedicamentPage({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  _RappelMedicamentPageState createState() => _RappelMedicamentPageState();
}

class _RappelMedicamentPageState extends State<RappelMedicamentPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _rappels = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Contrôleurs pour le formulaire
  final _medicationController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();
  
  // Variables pour le formulaire
  String? _selectedPatientId;
  List<TimeOfDay> _selectedTimes = [TimeOfDay.now()];
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isActive = true;
  
  @override
  void initState() {
    super.initState();
    _loadPatients();
    _loadRappels();
  }
  
  @override
  void dispose() {
    _medicationController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPatients() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Récupérer tous les patients (collection users)
      final patientsQuery = await _firestore
          .collection('users')
          .get();
      
      setState(() {
        _patients = patientsQuery.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return <String, dynamic>{
            'id': doc.id,
            'nom': data['nom'] ?? 'Nom inconnu',
            'prenom': data['prenom'] ?? 'Prénom inconnu',
            'email': data['email'] ?? '',
          };
        }).toList();
        
        // Pré-sélectionner le patient si un patientId est fourni
        if (widget.patientId != null) {
          _selectedPatientId = widget.patientId;
          
          // Vérifier si le patient est dans la liste, sinon l'ajouter
          final patientExists = _patients.any((p) => p['id'] == widget.patientId);
          if (!patientExists && widget.patientName != null) {
            // Ajouter le patient à la liste s'il n'y est pas
            _patients.add({
              'id': widget.patientId,
              'nom': widget.patientName!.split(' ').last,
              'prenom': widget.patientName!.split(' ').first,
              'email': '',
            });
          }
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des patients: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadRappels() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      Query query = _firestore
          .collection('rappel')
          .where('doctorId', isEqualTo: user.uid);
      
      // Si un patientId est spécifié, filtrer par patient
      if (widget.patientId != null) {
        query = query.where('patientId', isEqualTo: widget.patientId);
      }
      
      final rappelsQuery = await query.get();
      
      setState(() {
        _rappels = rappelsQuery.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return <String, dynamic>{
            'id': doc.id,
            ...data,
          };
        }).toList();
        
        // Vérifier et désactiver les rappels expirés
        _checkAndDeactivateExpiredRappels();
        
        // Trier manuellement par date de création (plus récent en premier)
        _rappels.sort((a, b) {
          final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des rappels: $e';
      });
    }
  }
  
  Future<void> _checkAndDeactivateExpiredRappels() async {
    final now = DateTime.now();
    final expiredRappels = <String>[];
    
    for (final rappel in _rappels) {
      final endDate = (rappel['endDate'] as Timestamp?)?.toDate();
      if (endDate != null && endDate.isBefore(now) && (rappel['isActive'] == true)) {
        expiredRappels.add(rappel['id']);
      }
    }
    
    // Désactiver les rappels expirés
    for (final rappelId in expiredRappels) {
      try {
        await _firestore.collection('rappel').doc(rappelId).update({
          'isActive': false,
          'expiredAt': Timestamp.now(),
        });
      } catch (e) {
        print('Erreur lors de la désactivation du rappel $rappelId: $e');
      }
    }
    
    // Mettre à jour la liste locale
    if (expiredRappels.isNotEmpty) {
      setState(() {
        for (final rappel in _rappels) {
          if (expiredRappels.contains(rappel['id'])) {
            rappel['isActive'] = false;
            rappel['expiredAt'] = Timestamp.now();
          }
        }
      });
    }
  }
  
  Future<void> _createRappel() async {
    if (_medicationController.text.isEmpty) {
      _showSnackBar('Veuillez saisir le médicament', Colors.blue);
      return;
    }
    
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Utiliser directement l'ID du patient concerné
      final patientId = widget.patientId ?? _selectedPatientId;
      if (patientId == null) {
        _showSnackBar('Aucun patient sélectionné', Colors.blue);
        return;
      }
      
      // Récupérer les informations du patient
      String patientName = 'Patient inconnu';
      try {
        final patient = _patients.firstWhere((p) => p['id'] == patientId);
        patientName = '${patient['prenom']} ${patient['nom']}';
      } catch (e) {
        // Si le patient n'est pas trouvé dans la liste locale, 
        // on utilise le nom fourni ou un nom par défaut
        patientName = widget.patientName ?? 'Patient inconnu';
      }
      
      // Convertir les heures en format string
      final timesList = _selectedTimes.map((time) => 
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
      ).toList();
      
      await _firestore.collection('rappel').add({
        'doctorId': user.uid,
        'patientId': patientId,
        'medication': _medicationController.text.trim(),
        'frequency': timesList.first, // Garder la première heure pour compatibilité
        'times': timesList, // Liste de toutes les heures
        'timestamp': Timestamp.now(),
        // Champs supplémentaires pour l'affichage
        'patientName': patientName,
        'dosage': _dosageController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'isActive': _isActive,
        'createdAt': Timestamp.now(),
        'lastReminderSent': null,
        'expiredAt': null,
      });
      
      _showSnackBar('Rappel créé avec succès', Colors.blue);
      _resetForm();
      _loadRappels();
    } catch (e) {
      _showSnackBar('Erreur lors de la création du rappel: $e', Colors.red);
    }
  }
  
  Future<void> _toggleRappelStatus(String rappelId, bool newStatus) async {
    try {
      await _firestore.collection('rappel').doc(rappelId).update({
        'isActive': newStatus,
        'updatedAt': Timestamp.now(),
      });
      
      _showSnackBar(
        newStatus ? 'Rappel activé' : 'Rappel désactivé',
        newStatus ? Colors.blue : Colors.blue.shade300,
      );
      _loadRappels();
    } catch (e) {
      _showSnackBar('Erreur lors de la mise à jour: $e', Colors.red);
    }
  }
  
  Future<void> _deleteRappel(String rappelId) async {
    try {
      await _firestore.collection('rappel').doc(rappelId).delete();
      _showSnackBar('Rappel supprimé', Colors.blue);
      _loadRappels();
    } catch (e) {
      _showSnackBar('Erreur lors de la suppression: $e', Colors.red);
    }
  }
  
  void _resetForm() {
    _medicationController.clear();
    _dosageController.clear();
    _instructionsController.clear();
    _selectedPatientId = null;
    _selectedTimes = [TimeOfDay.now()];
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 7));
    _isActive = true;
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  Future<void> _selectTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index],
    );
    if (picked != null) {
      setState(() {
        _selectedTimes[index] = picked;
      });
    }
  }
  
  void _addTime() {
    setState(() {
      _selectedTimes.add(TimeOfDay.now());
    });
  }
  
  void _removeTime(int index) {
    if (_selectedTimes.length > 1) {
      setState(() {
        _selectedTimes.removeAt(index);
      });
    }
  }
  
  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(picked)) {
          _endDate = picked.add(const Duration(days: 7));
        }
      });
    }
  }
  
  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }
  
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.patientId != null 
            ? 'Rappels - ${widget.patientName ?? 'Patient'}'
            : 'Rappels de Médicaments',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadRappels();
              _loadPatients();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: GoogleFonts.roboto(
                          color: theme.colorScheme.error,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = '';
                            _isLoading = true;
                          });
                          _loadPatients();
                          _loadRappels();
                        },
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Liste des rappels
                    Expanded(
                      child: _rappels.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.medication_outlined,
                                    size: 64,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucun rappel trouvé',
                                    style: GoogleFonts.roboto(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.patientId != null 
                                      ? 'Aucun rappel pour ce patient'
                                      : 'Créez votre premier rappel de médicament',
                                    style: GoogleFonts.roboto(
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _rappels.length,
                              itemBuilder: (context, index) {
                                final rappel = _rappels[index];
                                return _buildRappelCard(rappel, theme);
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRappelDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau Rappel'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
  
  Widget _buildRappelCard(Map<String, dynamic> rappel, ThemeData theme) {
    final isActive = rappel['isActive'] ?? false;
    final startDate = (rappel['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final endDate = (rappel['endDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final frequency = rappel['frequency'] ?? '00:00';
    final times = (rappel['times'] as List<dynamic>?)?.cast<String>() ?? [frequency];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec statut
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.blue : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'ACTIF' : 'INACTIF',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'toggle':
                        _toggleRappelStatus(rappel['id'], !isActive);
                        break;
                      case 'delete':
                        _showDeleteConfirmation(rappel['id']);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.pause : Icons.play_arrow,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Désactiver' : 'Activer'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Supprimer', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Informations du patient
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 20,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  rappel['patientName'] ?? 'Patient inconnu',
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Médicament
            Row(
              children: [
                Icon(
                  Icons.medication,
                  size: 20,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rappel['medication'] ?? 'Médicament non spécifié',
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            if (rappel['dosage']?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  'Dosage: ${rappel['dosage']}',
                  style: GoogleFonts.roboto(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
            
            if (rappel['instructions']?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  'Instructions: ${rappel['instructions']}',
                  style: GoogleFonts.roboto(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Horaires et dates
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Heures: ${times.join(', ')}',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Du ${DateFormat('dd/MM/yyyy').format(startDate)} au ${DateFormat('dd/MM/yyyy').format(endDate)}',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCreateRappelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Nouveau Rappel de Médicament',
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sélection du patient (seulement si pas de patientId spécifié)
              if (widget.patientId == null) ...[
                DropdownButtonFormField<String>(
                  value: _selectedPatientId,
                  decoration: const InputDecoration(
                    labelText: 'Patient *',
                    border: OutlineInputBorder(),
                  ),
                  items: _patients.map((patient) {
                    return DropdownMenuItem<String>(
                      value: patient['id'] as String,
                      child: Text('${patient['prenom']} ${patient['nom']}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPatientId = value;
                    });
                  },
                ),
                
                const SizedBox(height: 16),
              ] else ...[
                // Affichage du patient sélectionné
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Patient: ${widget.patientName ?? 'Patient sélectionné'}',
                        style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
              
              // Médicament
              TextField(
                controller: _medicationController,
                decoration: const InputDecoration(
                  labelText: 'Médicament *',
                  border: OutlineInputBorder(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Dosage
              TextField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage',
                  border: OutlineInputBorder(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Instructions
              TextField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 16),
              
              // Heures du rappel
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Heures du rappel',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_selectedTimes.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(index),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(_selectedTimes[index].format(context)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_selectedTimes.length > 1) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _removeTime(index),
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addTime,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une heure'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Date de début
              InkWell(
                onTap: _selectStartDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date de début',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Date de fin
              InkWell(
                onTap: _selectEndDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date de fin',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Statut actif
              SwitchListTile(
                title: const Text('Rappel actif'),
                subtitle: const Text('Le rappel sera envoyé au patient'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetForm();
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _createRappel();
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteConfirmation(String rappelId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce rappel ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteRappel(rappelId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
