import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

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
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAllActiveReminders();
    });
  }

  // Vérifier tous les rappels actifs
  Future<void> _checkAllActiveReminders() async {
    try {
      final now = DateTime.now();
      
      // Récupérer tous les rappels actifs
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
  Future<void> _checkAndSendReminder(String patientId, Map<String, dynamic> rappelData, DateTime now) async {
    try {
      final times = (rappelData['times'] as List<dynamic>?)?.cast<String>() ?? 
                   [rappelData['frequency'] ?? '00:00'];
      final startDate = (rappelData['startDate'] as Timestamp?)?.toDate();
      final endDate = (rappelData['endDate'] as Timestamp?)?.toDate();
      
      // Vérifier si on est dans la période de validité
      if (startDate != null && now.isBefore(startDate)) return;
      if (endDate != null && now.isAfter(endDate)) return;
      
      // Vérifier si c'est l'heure d'un des rappels
      bool shouldSendReminder = false;
      for (final timeStr in times) {
        final timeParts = timeStr.split(':');
        if (timeParts.length == 2) {
          final reminderHour = int.tryParse(timeParts[0]) ?? 0;
          final reminderMinute = int.tryParse(timeParts[1]) ?? 0;
          
          if (now.hour == reminderHour && now.minute == reminderMinute) {
            shouldSendReminder = true;
            break;
          }
        }
      }
      
      if (shouldSendReminder) {
        // Vérifier si on a déjà envoyé le rappel aujourd'hui
        final today = DateTime(now.year, now.month, now.day);
        final lastReminderSent = (rappelData['lastReminderSent'] as Timestamp?)?.toDate();
        
        if (lastReminderSent == null || 
            DateTime(lastReminderSent.year, lastReminderSent.month, lastReminderSent.day).isBefore(today)) {
          
          // Envoyer la notification
          await _sendMedicationReminderNotification(
            patientId,
            rappelData['medication'] ?? 'Médicament',
            rappelData['dosage'] ?? 'Selon prescription',
            rappelData['instructions'] ?? '',
          );
          
          // Mettre à jour la date du dernier rappel envoyé
          await _firestore.collection('rappel').doc(rappelData['id']).update({
            'lastReminderSent': Timestamp.now(),
          });
        }
      }
    } catch (e) {
      print('Erreur lors de l\'envoi du rappel: $e');
    }
  }

  // Envoyer une notification de rappel de médicament
  Future<void> _sendMedicationReminderNotification(
    String patientId,
    String medication,
    String dosage,
    String instructions,
  ) async {
    try {
      // Récupérer le token FCM du patient
      final patientDoc = await _firestore.collection('users').doc(patientId).get();
      final fcmToken = patientDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken != null) {
        // Envoyer la notification push via FCM
        await _sendFCMPushNotification(
          fcmToken,
          'Rappel de médicament',
          'Il est temps de prendre votre $medication${dosage.isNotEmpty ? ' ($dosage)' : ''}',
          {
            'type': 'medication_reminder',
            'medication': medication,
            'dosage': dosage,
            'instructions': instructions,
          },
        );
      }
      
      // Envoyer aussi une notification locale
      await _sendLocalNotification(
        'Rappel de médicament',
        'Il est temps de prendre votre $medication${dosage.isNotEmpty ? ' ($dosage)' : ''}',
      );
      
    } catch (e) {
      print('Erreur lors de l\'envoi de la notification: $e');
    }
  }

  // Envoyer une notification push via FCM
  Future<void> _sendFCMPushNotification(
    String fcmToken,
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    try {
      const String serverKey = 'YOUR_FCM_SERVER_KEY'; // Remplacez par votre clé serveur FCM
      
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': fcmToken,
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
          },
          'data': data,
        }),
      );
      
      if (response.statusCode == 200) {
        print('Notification push envoyée avec succès');
      } else {
        print('Erreur lors de l\'envoi de la notification push: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de l\'envoi de la notification push: $e');
    }
  }

  // Envoyer une notification locale
  Future<void> _sendLocalNotification(String title, String body) async {
    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Rappels de médicaments',
            channelDescription: 'Notifications pour les rappels de médicaments',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('Erreur lors de l\'envoi de la notification locale: $e');
    }
  }

  // Arrêter le service
  void dispose() {
    _reminderTimer?.cancel();
  }
}
