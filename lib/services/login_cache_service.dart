import 'package:shared_preferences/shared_preferences.dart';

class LoginCacheService {
  static const String _emailKey = 'cached_email';
  static const String _passwordKey = 'cached_password';
  static const String _rememberMeKey = 'remember_me';
  static const String _autoLoginKey = 'auto_login';

  // Sauvegarder les informations de connexion
  static Future<void> saveLoginCredentials({
    required String email,
    required String password,
    required bool rememberMe,
    bool autoLogin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (rememberMe) {
      await prefs.setString(_emailKey, email);
      await prefs.setString(_passwordKey, password);
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setBool(_autoLoginKey, autoLogin);
    } else {
      // Si "Se souvenir de moi" n'est pas activé, supprimer les données
      await prefs.remove(_emailKey);
      await prefs.remove(_passwordKey);
      await prefs.setBool(_rememberMeKey, false);
      await prefs.setBool(_autoLoginKey, false);
    }
  }

  // Récupérer l'email mis en cache
  static Future<String?> getCachedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  // Récupérer le mot de passe mis en cache
  static Future<String?> getCachedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_passwordKey);
  }

  // Vérifier si "Se souvenir de moi" est activé
  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  // Vérifier si la connexion automatique est activée
  static Future<bool> isAutoLoginEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoLoginKey) ?? false;
  }

  // Effacer toutes les informations de connexion mises en cache
  static Future<void> clearCachedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_passwordKey);
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_autoLoginKey);
  }

  // Vérifier s'il y a des informations de connexion mises en cache
  static Future<bool> hasCachedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_emailKey);
    final password = prefs.getString(_passwordKey);
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
    
    return rememberMe && email != null && email.isNotEmpty && password != null && password.isNotEmpty;
  }
}
