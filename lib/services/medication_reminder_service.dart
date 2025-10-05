import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class MedicationReminderService {
  static final MedicationReminderService _instance = MedicationReminderService._internal();
  factory MedicationReminderService() => _instance;
  MedicationReminderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Timer? _reminderTimer;

  // Initialiser le service
  Future<void> initialize() async {
    await _initializeNotifications();
    _startReminderCheck();
  }

  // Initialiser les notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(initializationSettings);
  }

  // Démarrer la vérification des rappels
  void _startReminderCheck() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkAllUserReminders();
    });
  }

  // Vérifier tous les rappels actifs depuis la collection rappel
  Future<void> _checkAllUserReminders() async {
    try {
      final now = DateTime.now();
      
      // Récupérer tous les rappels actifs depuis la collection rappel
      final activeReminders = await _firestore
          .collection('rappel')
          .where('isActive', isEqualTo: true)
          .get();

      for (var reminderDoc in activeReminders.docs) {
        final rappelData = reminderDoc.data();
        final patientId = rappelData['patientId'] as String?;
        
        if (patientId != null) {
          await _checkAndSendReminder(patientId, rappelData, now);
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification des rappels: $e');
    }
  }

  // Vérifier et envoyer un rappel spécifique
  Future<void> _checkAndSendReminder(String userId, Map<String, dynamic> rappelData, DateTime now) async {
    try {
      final reminderTime = rappelData['reminderTime'] as String?;
      if (reminderTime == null) return;

      final timeParts = reminderTime.split(':');
      final reminderHour = int.parse(timeParts[0]);
      final reminderMinute = int.parse(timeParts[1]);

      // Vérifier si c'est l'heure du rappel
      if (now.hour == reminderHour && now.minute == reminderMinute) {
        // Vérifier si la date de fin n'est pas dépassée
        final endDate = rappelData['endDate'] as Timestamp?;
        if (endDate != null && endDate.toDate().isBefore(now)) {
          // Rappel expiré, le désactiver
          await _deactivateExpiredReminder(userId);
          return;
        }

        // Envoyer la notification
        await _sendMedicationReminderNotification(
          rappelData['medication'] ?? 'Médicament',
          rappelData['dosage'] ?? 'Selon prescription',
        );
      }
    } catch (e) {
      print('Erreur lors de la vérification du rappel pour $userId: $e');
    }
  }

  // Désactiver un rappel expiré
  Future<void> _deactivateExpiredReminder(String userId) async {
    try {
      // Trouver et désactiver le rappel dans la collection rappel
      final reminders = await _firestore
          .collection('rappel')
          .where('patientId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();
      
      for (var doc in reminders.docs) {
        await doc.reference.update({'isActive': false});
        print('Rappel expiré désactivé pour le patient $userId');
      }
    } catch (e) {
      print('Erreur lors de la désactivation du rappel pour $userId: $e');
    }
  }

  // Envoyer une notification de rappel
  Future<void> _sendMedicationReminderNotification(String medication, String dosage) async {
    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Rappel médicament',
        'Il est temps de prendre $medication - $dosage',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Rappels médicaments',
            channelDescription: 'Notifications pour les rappels de médicaments',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF2196F3), // Bleu par défaut
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('Erreur lors de l\'envoi de la notification: $e');
    }
  }

  // Créer un rappel de médicament
  Future<bool> createMedicationReminder({
    required String patientId,
    required String patientName,
    required String doctorId,
    required String medication,
    required String dosage,
    required String frequency,
    required DateTime startDate,
    required DateTime endDate,
    required String reminderTime,
  }) async {
    try {
      // Vérifier que l'utilisateur connecté est bien un médecin
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('Erreur: Aucun utilisateur connecté');
        return false;
      }

      // Vérifier que l'utilisateur existe dans la collection doctors
      final doctorDoc = await _firestore
          .collection('doctors')
          .doc(currentUser.uid)
          .get();
      
      if (!doctorDoc.exists) {
        print('Erreur: L\'utilisateur connecté n\'est pas un médecin');
        return false;
      }

      // Vérifier que le doctorId correspond à l'utilisateur connecté
      if (doctorId != currentUser.uid) {
        print('Erreur: Le doctorId ne correspond pas à l\'utilisateur connecté');
        return false;
      }

      // Vérifier que le patient existe dans la collection users
      final patientDoc = await _firestore
          .collection('users')
          .doc(patientId)
          .get();
      
      if (!patientDoc.exists) {
        print('Erreur: Le patient n\'existe pas dans la collection users');
        return false;
      }
      
      print('Patient trouvé: ${patientDoc.data()}');

      // Créer le document dans la collection rappel avec tous les champs
      final rappelData = {
        'patientId': patientId,
        'patientName': patientName,
        'doctorId': doctorId,
        'medication': medication,
        'frequency': frequency,
        'timestamp': Timestamp.now(),
        'dosage': dosage,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'reminderTime': reminderTime,
        'isActive': true,
        'lastNotificationSent': null,
      };
      
      print('Tentative de création avec les données: $rappelData');
      print('Champs envoyés: ${rappelData.keys.toList()}');
      
      await _firestore.collection('rappel').add(rappelData);

      print('Rappel créé avec succès dans la collection rappel');

      return true;
    } catch (e) {
      print('Erreur lors de la création du rappel: $e');
      return false;
    }
  }

  // Nettoyer les rappels expirés
  Future<void> cleanupExpiredReminders() async {
    try {
      final now = DateTime.now();
      
      // Nettoyer la collection rappel
      final expiredReminders = await _firestore
          .collection('rappel')
          .where('endDate', isLessThan: Timestamp.fromDate(now))
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in expiredReminders.docs) {
        await doc.reference.update({'isActive': false});
        print('Rappel expiré nettoyé: ${doc.id}');
      }
      
      print('${expiredReminders.docs.length} rappels expirés ont été nettoyés');
    } catch (e) {
      print('Erreur lors du nettoyage des rappels expirés: $e');
    }
  }

  // Arrêter le service
  void dispose() {
    _reminderTimer?.cancel();
  }
}
