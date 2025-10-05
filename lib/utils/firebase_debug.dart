import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseDebug {
  static Future<void> debugUserStatus() async {
    try {
      print('=== DEBUG FIREBASE ===');
      
      // Vérifier l'utilisateur connecté
      final currentUser = FirebaseAuth.instance.currentUser;
      print('Utilisateur connecté: ${currentUser?.uid ?? 'Aucun'}');
      print('Email: ${currentUser?.email ?? 'Aucun'}');
      
      if (currentUser != null) {
        // Vérifier la collection doctors
        print('\n--- Collection DOCTORS ---');
        final doctorDoc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(currentUser.uid)
            .get();
        print('Document doctor existe: ${doctorDoc.exists}');
        if (doctorDoc.exists) {
          print('Données doctor: ${doctorDoc.data()}');
        }
        
        // Vérifier la collection users
        print('\n--- Collection USERS ---');
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        print('Document user existe: ${userDoc.exists}');
        if (userDoc.exists) {
          print('Données user: ${userDoc.data()}');
        }
        
        // Lister quelques documents de la collection doctors
        print('\n--- Liste des DOCTORS ---');
        final doctorsSnapshot = await FirebaseFirestore.instance
            .collection('doctors')
            .limit(5)
            .get();
        print('Nombre de doctors: ${doctorsSnapshot.docs.length}');
        for (var doc in doctorsSnapshot.docs) {
          print('Doctor ID: ${doc.id}, Data: ${doc.data()}');
        }
        
        // Lister quelques documents de la collection users
        print('\n--- Liste des USERS ---');
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .limit(5)
            .get();
        print('Nombre de users: ${usersSnapshot.docs.length}');
        for (var doc in usersSnapshot.docs) {
          print('User ID: ${doc.id}, Data: ${doc.data()}');
        }
      }
      
      print('=== FIN DEBUG ===');
    } catch (e) {
      print('Erreur lors du debug: $e');
    }
  }
  
  static Future<void> testRappelCreation() async {
    try {
      print('=== TEST CRÉATION RAPPEL ===');
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('Aucun utilisateur connecté');
        return;
      }
      
      // Tester la création d'un document dans rappel avec TOUS les champs requis
      final testData = {
        'patientId': 'test_patient_id',
        'patientName': 'Test Patient',
        'doctorId': currentUser.uid,
        'medication': 'Test Médicament',
        'frequency': '1 fois par jour',
        'timestamp': Timestamp.now(),
        'dosage': 'Test dosage',
        'startDate': Timestamp.fromDate(DateTime.now()),
        'endDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
        'reminderTime': '08:00',
        'isActive': true,
        'lastNotificationSent': null,
      };
      
      print('Tentative de création avec: $testData');
      print('Champs envoyés: ${testData.keys.toList()}');
      
      final docRef = await FirebaseFirestore.instance
          .collection('rappel')
          .add(testData);
      
      print('Document créé avec succès! ID: ${docRef.id}');
      
      // Supprimer le document de test
      await docRef.delete();
      print('Document de test supprimé');
      
    } catch (e) {
      print('Erreur lors du test: $e');
    }
  }
  
  static Future<void> testSimpleRappelCreation() async {
    try {
      print('=== TEST SIMPLE CRÉATION RAPPEL ===');
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('Aucun utilisateur connecté');
        return;
      }
      
      // Test avec seulement les champs minimaux
      final testData = {
        'patientId': 'test_patient_id',
        'doctorId': currentUser.uid,
        'medication': 'Test Médicament',
        'frequency': '1 fois par jour',
        'timestamp': Timestamp.now(),
      };
      
      print('Tentative de création simple avec: $testData');
      print('Champs envoyés: ${testData.keys.toList()}');
      
      final docRef = await FirebaseFirestore.instance
          .collection('rappel')
          .add(testData);
      
      print('Document créé avec succès! ID: ${docRef.id}');
      
      // Supprimer le document de test
      await docRef.delete();
      print('Document de test supprimé');
      
    } catch (e) {
      print('Erreur lors du test simple: $e');
    }
  }
  
  static Future<void> testMinimalRappelCreation() async {
    try {
      print('=== TEST MINIMAL CRÉATION RAPPEL ===');
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('Aucun utilisateur connecté');
        return;
      }
      
      // Test avec seulement 3 champs absolument essentiels
      final testData = {
        'patientId': 'test_patient_id',
        'doctorId': currentUser.uid,
        'medication': 'Test Médicament',
      };
      
      print('Tentative de création minimale avec: $testData');
      print('Champs envoyés: ${testData.keys.toList()}');
      
      final docRef = await FirebaseFirestore.instance
          .collection('rappel')
          .add(testData);
      
      print('Document créé avec succès! ID: ${docRef.id}');
      
      // Supprimer le document de test
      await docRef.delete();
      print('Document de test supprimé');
      
    } catch (e) {
      print('Erreur lors du test minimal: $e');
    }
  }
  
  static Future<void> testCollectionExistence() async {
    try {
      print('=== TEST EXISTENCE COLLECTION RAPPEL ===');
      
      // Essayer de lire la collection (même vide)
      final snapshot = await FirebaseFirestore.instance
          .collection('rappel')
          .limit(1)
          .get();
      
      print('Collection rappel accessible: OUI');
      print('Nombre de documents: ${snapshot.docs.length}');
      
      // Essayer de créer un document très simple
      final simpleData = {
        'test': 'test',
        'timestamp': Timestamp.now(),
      };
      
      print('Tentative de création document simple...');
      final docRef = await FirebaseFirestore.instance
          .collection('rappel')
          .add(simpleData);
      
      print('Document simple créé avec succès! ID: ${docRef.id}');
      
      // Supprimer le document de test
      await docRef.delete();
      print('Document simple supprimé');
      
    } catch (e) {
      print('Erreur lors du test d\'existence: $e');
    }
  }


}
