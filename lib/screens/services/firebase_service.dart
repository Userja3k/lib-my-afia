import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Envoyer une demande de rendez-vous
  Future<void> sendRendezvousRequest(String specialty, String message) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('rendezvous').add({
        'userId': user.uid,
        'specialty': specialty,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'En attente',
      });
    }
  }

  // Récupérer les demandes de rendez-vous pour un médecin
  Stream<QuerySnapshot> getRendezvousRequests() {
    return _firestore.collection('rendezvous').orderBy('timestamp', descending: true).snapshots();
  }

  // Envoyer un message dans le chat
  Future<void> sendMessage(String doctorId, String message) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('messages').add({
        'senderId': user.uid,
        'receiverId': doctorId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // Récupérer les messages entre un patient et un médecin
  Stream<QuerySnapshot> getMessages(String doctorId) {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('messages')
          .where('senderId', isEqualTo: user.uid)
          .where('receiverId', isEqualTo: doctorId)
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
    return const Stream.empty();
  }
}
