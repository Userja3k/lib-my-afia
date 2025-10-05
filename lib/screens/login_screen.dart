import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'patient/patient_dashboard.dart';
import 'doctor/doctor_dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'package:hospital_virtuel/services/auth_service.dart';
import 'package:hospital_virtuel/services/login_cache_service.dart';

enum SnackBarType { success, error, warning, info }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  bool _isPasswordVisible = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late AnimationController _logoController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;

  late AnimationController _textController;
  late Animation<double> _textFadeAnimation;

  late AnimationController _loadingController;
  late List<Animation<double>> _dotAnimations;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _logoScaleAnimation = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );
    _logoRotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );
    _logoController.repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _textFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textController.forward();

    // Animation pour les points de chargement
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _dotAnimations = List.generate(3, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _loadingController,
          curve: Interval(
            index * 0.2, // Délai progressif pour chaque point
            (index * 0.2) + 0.6, // Durée d'animation
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    // Charger les informations de connexion mises en cache
    _loadCachedCredentials();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Charger les informations de connexion mises en cache et se connecter automatiquement
  Future<void> _loadCachedCredentials() async {
    try {
      final hasCredentials = await LoginCacheService.hasCachedCredentials();
      if (hasCredentials) {
        final email = await LoginCacheService.getCachedEmail();
        final password = await LoginCacheService.getCachedPassword();
        
        if (mounted) {
          setState(() {
            if (email != null) _emailController.text = email;
            if (password != null) _passwordController.text = password;
          });
          
          // Connexion automatique si les informations sont disponibles
          if (email != null && password != null) {
            // Attendre un peu pour que l'interface se charge
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              loginUser();
            }
          }
        }
      }
    } catch (e) {
      // En cas d'erreur, continuer sans les informations mises en cache
      print('Erreur lors du chargement des informations mises en cache: $e');
    }
  }


  void _showStyledSnackBar(BuildContext context, String message, SnackBarType type) {
    if (!mounted) return;

    Color backgroundColor;
    IconData iconData;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = const Color(0xFF4A90E2);
        iconData = Icons.check_circle_outline;
        break;
      case SnackBarType.error:
        backgroundColor = Colors.red.shade700;
        iconData = Icons.error_outline;
        break;
      case SnackBarType.warning:
        backgroundColor = Colors.orange.shade700;
        iconData = Icons.warning_amber_outlined;
        break;
      case SnackBarType.info:
        backgroundColor = const Color(0xFF4A90E2);
        iconData = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(iconData, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        margin: const EdgeInsets.all(10.0),
      ),
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showStyledSnackBar(context, 'E-mail de réinitialisation envoyé.', SnackBarType.success);
    } catch (e) {
      _showStyledSnackBar(context, "Erreur lors de l'envoi de l'e-mail.", SnackBarType.error);
    }
  }

  Future<void> loginUser() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showStyledSnackBar(context, 'Veuillez remplir tous les champs.', SnackBarType.warning);
      return;
    }

    setState(() {
      _isLoading = true;
    });
    _logoController.stop();
    _textController.reset();
    _loadingController.repeat();

    try {
      // Utiliser le nouveau service d'authentification
      UserCredential userCredential = await AuthService.signInWithEmailAndPassword(email, password);
      User? user = userCredential.user;

      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          _showStyledSnackBar(context, 'Session expirée, reconnectez-vous.', SnackBarType.warning);
          return;
        }

        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          if (user.emailVerified) {
            // Sauvegarder automatiquement les informations de connexion
            await LoginCacheService.saveLoginCredentials(
              email: email,
              password: password,
              rememberMe: true,
              autoLogin: true,
            );
            
            if (!mounted) return;
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => PatientDashboardContent()));
          } else {
            _showStyledSnackBar(context, 'Vérifiez votre e-mail avant de continuer.', SnackBarType.info);
            await AuthService.signOut();
          }
          return;
        }

        DocumentSnapshot doctorDoc =
            await FirebaseFirestore.instance.collection('doctors').doc(user.uid).get();

        if (doctorDoc.exists) {
          await FirebaseFirestore.instance.collection('doctors').doc(user.uid).update({
            'lastOnline': FieldValue.serverTimestamp(),
          });
          
          // Sauvegarder automatiquement les informations de connexion
          await LoginCacheService.saveLoginCredentials(
            email: email,
            password: password,
            rememberMe: true,
            autoLogin: true,
          );
          
          if (!mounted) return;
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const DoctorDashboard()));
          return;
        }

        _showStyledSnackBar(context, 'Compte introuvable.', SnackBarType.error);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      SnackBarType type = SnackBarType.error;

      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
          errorMessage = 'Email ou mot de passe incorrect.';
          type = SnackBarType.warning;
          break;
        case 'invalid-email':
          errorMessage = 'Adresse e-mail invalide.';
          type = SnackBarType.warning;
          break;
        case 'user-disabled':
          errorMessage = 'Compte désactivé.';
          break;
        case 'too-many-requests':
          errorMessage = 'Trop de tentatives. Réessayez plus tard.';
          type = SnackBarType.warning;
          break;
        default:
          errorMessage = 'Connexion échouée.';
      }
      _showStyledSnackBar(context, errorMessage, type);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _loadingController.stop();
        _logoController.repeat(reverse: true);
        _textController.forward();
      }
    }
  }

  Widget _buildLoadingAnimation() {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: _dotAnimations[index].value,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A90E2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Scaffold(
      backgroundColor: isMobile ? theme.colorScheme.surface : theme.scaffoldBackgroundColor,
      body: isMobile 
        ? SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _logoRotationAnimation.value,
                            child: Transform.scale(
                              scale: _logoScaleAnimation.value,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4A90E2).withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            'assets/images/img2.JPG',
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _textFadeAnimation,
                        child: Text(
                          "Connexion",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: _textFadeAnimation,
                        child: Text(
                          "Bienvenue sur votre espace santé",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Adresse e-mail',
                        icon: Icons.email_outlined,
                        theme: theme,
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordField(theme),
                      const SizedBox(height: 20),
                      if (!_isLoading)
                        ElevatedButton(
                          onPressed: loginUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Se connecter',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        )
                      else
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.3)),
                          ),
                          child: Center(
                            child: _buildLoadingAnimation(),
                          ),
                        ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () async {
                              if (_emailController.text.isNotEmpty) {
                                await sendPasswordResetEmail(_emailController.text.trim());
                              } else {
                                _showStyledSnackBar(context, 'Veuillez entrer votre e-mail.', SnackBarType.warning);
                              }
                            },
                            child: const Text(
                              'Mot de passe oublié ?',
                              style: TextStyle(color: Color(0xFF4A90E2)),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Pas de compte ?",
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));
                            },
                            child: const Text(
                              'Créer un compte',
                              style: TextStyle(color: Color(0xFF4A90E2)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 450),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A90E2).withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnimatedBuilder(
                            animation: _logoController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _logoRotationAnimation.value,
                                child: Transform.scale(
                                  scale: _logoScaleAnimation.value,
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4A90E2).withOpacity(0.5),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                'assets/images/img2.JPG',
                                width: 140,
                                height: 140,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FadeTransition(
                            opacity: _textFadeAnimation,
                            child: Text(
                              "Connexion",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A90E2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FadeTransition(
                            opacity: _textFadeAnimation,
                            child: Text(
                              "Bienvenue sur votre espace santé",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildTextField(
                            controller: _emailController,
                            hint: 'Adresse e-mail',
                            icon: Icons.email_outlined,
                            theme: theme,
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(theme),
                          const SizedBox(height: 20),
                          if (!_isLoading)
                            ElevatedButton(
                              onPressed: loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A90E2),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Se connecter',
                                style: TextStyle(fontSize: 18, color: Colors.white),
                              ),
                            )
                          else
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A90E2).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.3)),
                              ),
                              child: Center(
                                child: _buildLoadingAnimation(),
                              ),
                            ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  if (_emailController.text.isNotEmpty) {
                                    await sendPasswordResetEmail(_emailController.text.trim());
                                  } else {
                                    _showStyledSnackBar(context, 'Veuillez entrer votre e-mail.', SnackBarType.warning);
                                  }
                                },
                                child: const Text(
                                  'Mot de passe oublié ?',
                                  style: TextStyle(color: Color(0xFF4A90E2)),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Pas de compte ?",
                                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));
                                },
                                child: const Text(
                                  'Créer un compte',
                                  style: TextStyle(color: Color(0xFF4A90E2)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, required ThemeData theme}) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: theme.textTheme.bodyMedium?.color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
        prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: TextStyle(color: theme.textTheme.bodyMedium?.color),
      decoration: InputDecoration(
        hintText: 'Mot de passe',
        hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF4A90E2)),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: const Color(0xFF4A90E2),
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
      ),
    );
  }
}
