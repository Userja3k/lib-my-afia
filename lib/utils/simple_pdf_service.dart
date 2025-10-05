import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class SimplePdfService {
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Méthode principale pour extraire le texte d'un PDF
  static Future<String> extractTextFromPdf(String filePath) async {
    try {
      // Vérifier si le fichier existe
      final File file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Le fichier PDF n\'existe pas');
      }

      // Pour l'instant, nous allons utiliser une approche simplifiée
      // qui simule l'extraction de texte
      String extractedText = await _simulateTextExtraction(filePath);
      
      return extractedText.trim();
    } catch (e) {
      print('Erreur lors de l\'extraction du texte PDF: $e');
      throw Exception('Impossible de lire le fichier PDF: $e');
    }
  }

  /// Simule l'extraction de texte (méthode temporaire)
  static Future<String> _simulateTextExtraction(String filePath) async {
    try {
      // Cette méthode simule l'extraction de texte
      // En réalité, elle retourne un texte d'exemple basé sur le nom du fichier
      final String fileName = filePath.split('/').last.toLowerCase();
      
      // Simuler différents types de contenu selon le nom du fichier
      if (fileName.contains('ordonnance') || fileName.contains('prescription')) {
        return '''
        ORDONNANCE MÉDICALE
        
        Patient: Jean Dupont
        Date: 15/12/2024
        Médecin: Dr. Martin
        
        Médicaments prescrits:
        - Paracétamol 500mg: 2 comprimés 3x/jour
        - Ibuprofène 400mg: 1 comprimé 2x/jour
        - Amoxicilline 1g: 1 comprimé 2x/jour
        
        Durée du traitement: 7 jours
        Renouvellement: Non
        ''';
      } else if (fileName.contains('analyse') || fileName.contains('resultat')) {
        return '''
        RÉSULTATS D'ANALYSE
        
        Patient: Marie Martin
        Date: 10/12/2024
        Laboratoire: Labo Central
        
        Analyses effectuées:
        - Numération formule sanguine
        - Glycémie à jeun
        - Cholestérol total
        
        Résultats normaux
        ''';
      } else {
        return '''
        DOCUMENT PDF
        
        Ce document contient des informations médicales.
        Veuillez consulter votre médecin pour plus de détails.
        
        Médicaments mentionnés:
        - Paracétamol
        - Ibuprofène
        - Aspirine
        ''';
      }
    } catch (e) {
      return 'Erreur lors de la lecture du document PDF';
    }
  }

  /// Obtient les informations de base du PDF
  static Future<Map<String, dynamic>> getPdfInfo(String filePath) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Le fichier PDF n\'existe pas');
      }

      final Uint8List bytes = await file.readAsBytes();
      
      // Estimation du nombre de pages basée sur la taille
      final int estimatedPages = (bytes.length / 1000).round().clamp(1, 10);
      
      final Map<String, dynamic> info = {
        'pageCount': estimatedPages,
        'fileSize': bytes.length,
        'fileName': file.path.split('/').last,
        'filePath': file.path,
        'isValid': true,
      };
      
      return info;
    } catch (e) {
      print('Erreur lors de la récupération des informations PDF: $e');
      return {
        'pageCount': 0,
        'fileSize': 0,
        'fileName': '',
        'filePath': filePath,
        'isValid': false,
        'error': e.toString(),
      };
    }
  }

  /// Vérifie si un fichier est un PDF valide
  static Future<bool> isValidPdf(String filePath) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) {
        print('Fichier PDF n\'existe pas: $filePath');
        return false;
      }

      // Vérifier d'abord par extension
      final String extension = filePath.split('.').last.toLowerCase();
      if (extension == 'pdf') {
        print('Fichier PDF accepté par extension: $filePath');
        return true;
      }

      // Vérifier la signature si possible
      try {
        final Uint8List bytes = await file.readAsBytes();
        if (bytes.length < 4) {
          print('Fichier PDF trop petit: ${bytes.length} bytes');
          return false;
        }

        // Vérifier la signature PDF (%PDF)
        final String header = String.fromCharCodes(bytes.take(4));
        if (header == '%PDF') {
          print('Fichier PDF accepté par signature: $filePath');
          return true;
        }

        // Vérifier d'autres signatures PDF possibles
        if (bytes.length >= 8) {
          final String header8 = String.fromCharCodes(bytes.take(8));
          if (header8.contains('%PDF')) {
            print('Fichier PDF accepté par signature étendue: $filePath');
            return true;
          }
        }

        print('Fichier PDF rejeté - signature invalide: $filePath');
        return false;
      } catch (e) {
        print('Erreur lors de la lecture du fichier PDF: $e');
        // En cas d'erreur de lecture, on accepte par extension
        return extension == 'pdf';
      }
    } catch (e) {
      print('Erreur lors de la validation PDF: $e');
      // En cas d'erreur, on accepte le fichier si l'extension est .pdf
      final String extension = filePath.split('.').last.toLowerCase();
      return extension == 'pdf';
    }
  }

  /// Extrait les mots-clés médicaux du texte extrait
  static List<String> extractMedicalKeywords(String text) {
    final List<String> medicalKeywords = [
      'paracétamol', 'ibuprofène', 'aspirine', 'amoxicilline',
      'oméprazole', 'atorvastatine', 'metformine', 'lisinopril',
      'amlodipine', 'sertraline', 'doliprane', 'spasfon',
      'vitamine', 'calcium', 'fer', 'magnésium',
      'antibiotique', 'antidouleur', 'anti-inflammatoire',
      'comprimé', 'gélule', 'sirop', 'pommade',
      'mg', 'g', 'ml', 'mg/kg',
    ];

    final List<String> foundKeywords = [];
    final String lowerText = text.toLowerCase();

    for (String keyword in medicalKeywords) {
      if (lowerText.contains(keyword)) {
        foundKeywords.add(keyword);
      }
    }

    return foundKeywords.toSet().toList(); // Éviter les doublons
  }

  /// Libère les ressources
  static Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
