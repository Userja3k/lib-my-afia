import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImageReaderService {
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  static final ImageLabeler _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.7));

  /// Méthode principale pour analyser une image
  static Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Le fichier image n\'existe pas');
      }

      final Map<String, dynamic> results = {};

      // 1. Reconnaissance de texte (OCR)
      results['text'] = await extractTextFromImage(imagePath);
      
      // 2. Analyse d'image avec ML Kit
      results['labels'] = await analyzeImageLabels(imagePath);
      
      // 3. Détection de médicaments
      results['medications'] = extractMedicationsFromText(results['text']);
      
      // 4. Tentative d'analyse avec Google Lens (simulation)
      results['googleLensAnalysis'] = await _simulateGoogleLensAnalysis(imagePath);

      return results;
    } catch (e) {
      throw Exception('Erreur lors de l\'analyse de l\'image: $e');
    }
  }

  /// Extraire le texte d'une image avec OCR
  static Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      String extractedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += line.text + '\n';
        }
      }
      
      return extractedText.trim();
    } catch (e) {
      print('Erreur OCR: $e');
      return '';
    }
  }

  /// Analyser les labels d'une image
  static Future<List<String>> analyzeImageLabels(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);
      
      return labels.map((label) => label.label).toList();
    } catch (e) {
      print('Erreur analyse d\'image: $e');
      return [];
    }
  }

  /// Extraire les médicaments du texte
  static List<String> extractMedicationsFromText(String text) {
    final List<String> medicalKeywords = [
      'paracétamol', 'doliprane', 'dafalgan', 'efferalgan',
      'ibuprofène', 'nurofen', 'advil', 'spedifen',
      'aspirine', 'kardégic', 'aspegic',
      'amoxicilline', 'augmentin', 'clamoxyl',
      'oméprazole', 'mopral', 'zoltum',
      'atorvastatine', 'tahor', 'lipitor',
      'metformine', 'glucophage', 'metformax',
      'lisinopril', 'zestril', 'prinivil',
      'amlodipine', 'amlodis', 'norvasc',
      'sertraline', 'zoloft', 'lustral',
      'comprimé', 'gélule', 'sirop', 'pommade',
      'mg', 'g', 'ml', 'mg/kg', 'posologie',
      'traitement', 'ordonnance', 'prescription',
    ];

    final List<String> foundMedications = [];
    final String lowerText = text.toLowerCase();

    for (String keyword in medicalKeywords) {
      if (lowerText.contains(keyword)) {
        foundMedications.add(keyword);
      }
    }

    return foundMedications.toSet().toList();
  }

  /// Simuler l'analyse Google Lens
  static Future<Map<String, dynamic>> _simulateGoogleLensAnalysis(String imagePath) async {
    try {
      // Simulation de l'analyse Google Lens
      final String fileName = imagePath.split('/').last.toLowerCase();
      
      Map<String, dynamic> analysis = {
        'detectedObjects': [],
        'text': '',
        'medicalContent': false,
        'confidence': 0.85,
      };

      // Simuler la détection d'objets médicaux
      if (fileName.contains('ordonnance') || fileName.contains('prescription')) {
        analysis['detectedObjects'] = [
          'Document médical',
          'Texte manuscrit',
          'Signature',
          'Cachet médical'
        ];
        analysis['medicalContent'] = true;
        analysis['text'] = 'Document médical détecté avec haute confiance';
      } else if (fileName.contains('medicament') || fileName.contains('pillule')) {
        analysis['detectedObjects'] = [
          'Médicament',
          'Boîte de médicament',
          'Comprimé',
          'Pilulier'
        ];
        analysis['medicalContent'] = true;
        analysis['text'] = 'Médicament détecté';
      } else {
        analysis['detectedObjects'] = [
          'Document',
          'Texte',
          'Image'
        ];
        analysis['text'] = 'Document générique détecté';
      }

      return analysis;
    } catch (e) {
      return {
        'error': 'Erreur lors de l\'analyse Google Lens: $e',
        'detectedObjects': [],
        'text': '',
        'medicalContent': false,
        'confidence': 0.0,
      };
    }
  }

  /// Vérifier si un fichier est une image valide
  static Future<bool> isValidImage(String filePath) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) {
        print('Fichier image n\'existe pas: $filePath');
        return false;
      }

      final String extension = filePath.split('.').last.toLowerCase();
      final List<String> validExtensions = ['jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'];

      if (validExtensions.contains(extension)) {
        print('Fichier image accepté par extension: $filePath');
        return true;
      }

      print('Fichier image rejeté - extension invalide: $extension');
      return false;
    } catch (e) {
      print('Erreur lors de la validation image: $e');
      return false;
    }
  }

  /// Nettoyer les ressources
  static Future<void> dispose() async {
    await _textRecognizer.close();
    await _imageLabeler.close();
  }
}
