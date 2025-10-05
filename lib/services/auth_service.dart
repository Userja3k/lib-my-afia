import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_virtuel/services/login_cache_service.dart';

class AuthService {
  static const String _emailKey = 'cached_email';
  static const String _passwordKey = 'cached_password';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userIdKey = 'user_id';
  static const String _userTypeKey = 'user_type';

  // Vérifier si l'utilisateur est déjà connecté
  static Future<bool> isUserLoggedIn() async {
    try {
      // Vérifier Firebase Auth
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Vérifier si l'utilisateur existe toujours dans Firestore
        bool isValidUser = await _validateUserInFirestore(currentUser.uid);
        if (isValidUser) {
          return true;
        } else {
          // Utilisateur invalide, déconnecter
          await signOut();
          return false;
        }
      }
      
      // Vérifier le cache local
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      
      if (isLoggedIn) {
        // Essayer de se reconnecter automatiquement
        String? cachedEmail = prefs.getString(_emailKey);
        String? cachedPassword = prefs.getString(_passwordKey);
        
        if (cachedEmail != null && cachedPassword != null) {
          try {
            UserCredential userCredential = await FirebaseAuth.instance
                .signInWithEmailAndPassword(email: cachedEmail, password: cachedPassword);
            
            if (userCredential.user != null) {
              return true;
            }
          } catch (e) {
            // Échec de la reconnexion automatique, nettoyer le cache
            await _clearCache();
            return false;
          }
        }
      }
      
      return false;
    } catch (e) {
      print('Erreur lors de la vérification de connexion: $e');
      return false;
    }
  }

  // Se connecter et mettre en cache
  static Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      
      if (userCredential.user != null) {
        // Mettre en cache les identifiants
        await _cacheCredentials(email, password);
        
        // Déterminer le type d'utilisateur
        String userType = await _determineUserType(userCredential.user!.uid);
        
        // Sauvegarder les informations de session
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString(_userIdKey, userCredential.user!.uid);
        await prefs.setString(_userTypeKey, userType);
      }
      
      return userCredential;
    } catch (e) {
      print('Erreur de connexion: $e');
      rethrow;
    }
  }

  // Se déconnecter et nettoyer le cache
  static Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await _clearCache();
      
      // Effacer également les informations de connexion mises en cache
      // sauf si l'utilisateur a activé "Se souvenir de moi"
      final rememberMe = await LoginCacheService.isRememberMeEnabled();
      if (!rememberMe) {
        await LoginCacheService.clearCachedCredentials();
      }
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
    }
  }

  // Mettre en cache les identifiants
  static Future<void> _cacheCredentials(String email, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
    await prefs.setString(_passwordKey, password);
  }

  // Nettoyer le cache
  static Future<void> _clearCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_passwordKey);
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userTypeKey);
  }

  // Déterminer le type d'utilisateur (patient ou médecin)
  static Future<String> _determineUserType(String userId) async {
    try {
      // Vérifier d'abord dans la collection doctors
      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
          .collection('doctors').doc(userId).get();
      
      if (doctorDoc.exists) {
        return 'doctor';
      }
      
      // Vérifier dans la collection users
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        return 'patient';
      }
      
      return 'unknown';
    } catch (e) {
      print('Erreur lors de la détermination du type d\'utilisateur: $e');
      return 'unknown';
    }
  }

  // Valider l'utilisateur dans Firestore
  static Future<bool> _validateUserInFirestore(String userId) async {
    try {
      // Vérifier dans les deux collections
      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
          .collection('doctors').doc(userId).get();
      
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users').doc(userId).get();
      
      return doctorDoc.exists || userDoc.exists;
    } catch (e) {
      print('Erreur lors de la validation Firestore: $e');
      return false;
    }
  }

  // Obtenir le type d'utilisateur actuel
  static Future<String> getCurrentUserType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userTypeKey) ?? 'unknown';
  }

  // Obtenir l'ID de l'utilisateur actuel
  static Future<String?> getCurrentUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Vérifier si l'utilisateur veut rester connecté
  static Future<bool> shouldStayLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }
}
