import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Modèle Message
class Message {
  final String senderId;
  final String receiverId;
  final String message;
  final Timestamp timestamp;

  Message({
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
  });

  // Crée un message à partir des données stockées dans Firestore
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;  // Convertir le document en Map
    return Message(
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}

// Page Messages (affichage des messages)
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  // Fonction pour afficher les messages à partir de Firestore
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('messages')
            .orderBy('timestamp', descending: true) // Tri par timestamp
            .snapshots(),
        builder: (context, snapshot) {
          // Affichage d'un indicateur de chargement pendant la récupération des données
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Gestion des erreurs
          if (snapshot.hasError) {
            return const Center(child: Text('Erreur de connexion.'));
          }

          // Récupération des messages depuis Firestore
          final messages = snapshot.data!.docs.map((doc) {
            return Message.fromFirestore(doc); // Création des objets Message
          }).toList();

          // Affichage des messages dans une ListView
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];

              return ListTile(
                title: Text(message.message),  // Affiche le texte du message
                subtitle: Text('De: ${message.senderId}'),  // Affiche l'expéditeur
                trailing: Text(
                  message.timestamp.toDate().toString(),  // Affiche la date du message
                  style: const TextStyle(fontSize: 12.0),
                ),
                onTap: () {
                  // Action au clic sur le message (par exemple, ouvrir la conversation)
                  // Tu peux ajouter une fonctionnalité ici pour ouvrir une conversation spécifique
                },
              );
            },
          );
        },
      ),
    );
  }
}
