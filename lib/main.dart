import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'package:hospital_virtuel/providers/theme_provider.dart';
import 'package:hospital_virtuel/screens/login_screen.dart';
import 'package:hospital_virtuel/screens/patient/patient_dashboard.dart';
import 'package:hospital_virtuel/screens/doctor/doctor_dashboard.dart';
import 'package:hospital_virtuel/services/auth_service.dart';

// Notifications locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print("✅ Firebase initialisé");
  } catch (e) {
    print("❌ Erreur Firebase: $e");
  }

  // Localisation pour DateFormat
  await initializeDateFormatting('fr_FR', null);

  // Initialisation notifications
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AFYA BORA',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.blue,
            ),
           darkTheme: ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF121212),
  primaryColor: Colors.tealAccent,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1F1F1F),
    foregroundColor: Colors.white,
  ),
  cardColor: const Color(0xFF1E1E1E),
  textTheme: ThemeData.dark().textTheme.copyWith(
        // Styles personnalisés
        titleLarge: ThemeData.dark().textTheme.titleLarge?.copyWith(color: Colors.tealAccent, fontWeight: FontWeight.bold),
        labelLarge: ThemeData.dark().textTheme.labelLarge?.copyWith(color: Colors.tealAccent),
        bodyMedium: ThemeData.dark().textTheme.bodyMedium?.copyWith(color: Colors.white70),
        // Assurer que les autres styles de titre importants sont blancs pour éviter qu'ils n'apparaissent en noir.
        titleMedium: ThemeData.dark().textTheme.titleMedium?.copyWith(color: Colors.white),
        titleSmall: ThemeData.dark().textTheme.titleSmall?.copyWith(color: Colors.white),
      ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Colors.tealAccent,
    foregroundColor: Colors.black,
  ),
  iconTheme: const IconThemeData(color: Colors.tealAccent),
  colorScheme: const ColorScheme.dark(
    primary: Colors.tealAccent,
    secondary: Colors.cyanAccent,
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    onPrimary: Colors.black,
    onSecondary: Colors.black,
    onBackground: Colors.white,
    onSurface: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.tealAccent,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFF2A2A2A),
    labelStyle: TextStyle(color: Colors.tealAccent),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.tealAccent, width: 2),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.redAccent),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.redAccent, width: 2),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
),

            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const LoginScreen(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String _userType = 'unknown';

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      bool isLoggedIn = await AuthService.isUserLoggedIn();
      String userType = 'unknown';
      
      if (isLoggedIn) {
        userType = await AuthService.getCurrentUserType();
      }
      
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _userType = userType;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification de l\'authentification: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _userType = 'unknown';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isLoggedIn) {
      // Rediriger directement vers le dashboard approprié
      if (_userType == 'doctor') {
        return const DoctorDashboard();
      } else if (_userType == 'patient') {
        return PatientDashboardContent();
      } else {
        // Type d'utilisateur inconnu, retourner à la connexion
        return const LoginScreen();
      }
    }

    // Utilisateur non connecté, afficher WelcomeScreen
    return const LoginScreen(); // Changed from WelcomeScreen to LoginScreen
  }
}
