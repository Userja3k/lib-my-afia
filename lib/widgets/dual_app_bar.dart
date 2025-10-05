import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Un widget AppBar personnalisé qui affiche deux barres de titre
/// avec un dégradé fluide entre les deux.
class DualAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget mainTitle;
  final Widget secondaryTitle;
  final Color mainColor;
  final Color secondaryColor;
  final List<Widget>? mainActions;
  final List<Widget>? secondaryActions;
  final double gradientHeight;
  final double mainAppBarHeight;
  final double secondaryAppBarHeight;

  const DualAppBar({
    super.key,
    required this.mainTitle,
    required this.secondaryTitle,
    this.mainColor = Colors.blue,
    this.secondaryColor = const Color(0xFFF5F5DC), // Beige
    this.mainActions,
    this.secondaryActions,
    this.gradientHeight = 20.0,
    this.mainAppBarHeight = kToolbarHeight,
    this.secondaryAppBarHeight = kToolbarHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4.0, // Ombre globale pour l'ensemble du bloc
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. AppBar principale (en haut)
          AppBar(
            title: mainTitle,
            actions: mainActions,
            backgroundColor: mainColor,
            elevation: 0, // Pas d'ombre pour une transition fluide
            toolbarHeight: mainAppBarHeight,
            // Assurez-vous que le style du texte est lisible sur la couleur principale
            titleTextStyle: GoogleFonts.lato(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),

          // 2. Le dégradé pour la transition
          Container(
            height: gradientHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  mainColor,
                  secondaryColor,
                ],
              ),
            ),
          ),

          // 3. AppBar secondaire (en bas)
          AppBar(
            title: secondaryTitle,
            actions: secondaryActions,
            backgroundColor: secondaryColor,
            elevation: 0, // Pas d'ombre pour une apparence intégrée
            toolbarHeight: secondaryAppBarHeight,
            automaticallyImplyLeading: false, // Très important: évite un bouton retour en double
            // Assurez-vous que le style du texte est lisible sur la couleur secondaire
            titleTextStyle: GoogleFonts.lato(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
        ],
      ),
    );
  }

  /// La hauteur totale de notre widget AppBar personnalisé.
  /// C'est la somme des deux barres et du dégradé.
  @override
  Size get preferredSize => Size.fromHeight(
        mainAppBarHeight + secondaryAppBarHeight + gradientHeight,
      );
}

