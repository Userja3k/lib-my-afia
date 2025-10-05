import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart'; // Pour le zoom et le panoramique

class FullScreenImagePage extends StatelessWidget {
  final ImageProvider imageProvider; // Champ corrigé
  final String tag; // Pour l'animation Hero, maintenant requis
  final bool showConfirmButton; // Pour afficher le bouton de confirmation

  const FullScreenImagePage({
    super.key,
    required this.imageProvider,
    required this.tag,
    this.showConfirmButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fond noir pour une meilleure immersion
      appBar: AppBar(
        backgroundColor: Colors.transparent, // AppBar transparente
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Icône de retour blanche
      ),
      body: Center(
        child: Hero(
          tag: tag,
          child: PhotoView(
            imageProvider: imageProvider, // Utiliser this.imageProvider
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2.0,
            initialScale: PhotoViewComputedScale.contained,
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 50,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: showConfirmButton
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pop(context, true); // Retourne true pour indiquer la confirmation
              },
              label: const Text("Confirmer et Envoyer"),
              icon: const Icon(Icons.check),
              backgroundColor: Theme.of(context).primaryColor,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
