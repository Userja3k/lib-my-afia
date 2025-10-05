import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _otherHandicapController = TextEditingController();
  final _otherAllergyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _avenueController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedBloodType;
  String? _selectedHandicap;
  String? _selectedAllergy;
  String? _selectedGender;
  String? _selectedCountry;
  String? _selectedProvince;
  String? _selectedCity;

  bool _isLoading = false;
  bool _isConfirmPasswordVisible = false;
  bool _isPasswordVisible = false;
  bool _isVerificationEmailSent = false;
  bool _isLoadingProvinces = false;
  bool _isLoadingCities = false;

  final List<String> bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Inconnu'];
  final List<String> disabilities = ['Aucun', 'Diabète', 'Cancer', 'Cécité', 'Surdité', 'Autre'];
  final List<String> allergiesList = ['Aucune', 'Médicaments', 'Alimentaires', 'Piqûres d\'insectes', 'Pollen', 'Acariens', 'Animaux', 'Autre'];
  final List<String> genders = ['Homme', 'Femme'];
  
  List<Map<String, dynamic>> countries = [];
  List<String> _provincesList = [];
  List<String> _citiesList = [];

  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'CD');

  // Données spécifiques pour la RDC
  static const String rdc = 'République démocratique du Congo';
  final Map<String, List<String>> _rdcProvincesAndCities = {
    'Bas-Uele': ['Buta', 'Aketi', 'Bondo'],
    'Équateur': ['Mbandaka', 'Bikoro', 'Lukolela'],
    'Haut-Katanga': ['Lubumbashi', 'Likasi', 'Kasumbalesa'],
    'Haut-Lomami': ['Kamina', 'Kabongo', 'Malemba-Nkulu'],
    'Haut-Uele': ['Isiro', 'Watsa', 'Faradje'],
    'Ituri': ['Bunia', 'Mahagi', 'Aru'],
    'Kasaï': ['Tshikapa', 'Ilebo', 'Mweka'],
    'Kasaï central': ['Kananga', 'Demba', 'Dibaya'],
    'Kasaï oriental': ['Mbuji-Mayi', 'Kabinda', 'Mwene-Ditu'],
    'Kinshasa': ['Kinshasa', 'Masina', 'Ndjili'],
    'Kongo-Central': ['Matadi', 'Boma', 'Moanda'],
    'Kwango': ['Kenge', 'Popokabaka', 'Feshi'],
    'Kwilu': ['Bandundu', 'Kikwit', 'Idiofa'],
    'Lomami': ['Kabinda', 'Lubao', 'Luputa'],
    'Lualaba': ['Kolwezi', 'Mutshatsha', 'Dilolo'],
    'Mai-Ndombe': ['Inongo', 'Kutu', 'Oshwe'],
    'Maniema': ['Kindu', 'Kasongo', 'Punia'],
    'Mongala': ['Lisala', 'Bumba', 'Bongandanga'],
    'Nord-Kivu': ['Goma', 'Beni', 'Butembo'],
    'Nord-Ubangi': ['Gbadolite', 'Bosobolo', 'Mobayi-Mbongo'],
    'Sankuru': ['Lusambo', 'Lodja', 'Katako-Kombe'],
    'Sud-Kivu': ['Bukavu', 'Uvira', 'Baraka'],
    'Sud-Ubangi': ['Gemena', 'Zongo', 'Libenge'],
    'Tanganyika': ['Kalemie', 'Manono', 'Kongolo'],
    'Tshopo': ['Kisangani', 'Bafwasende', 'Ubundu'],
    'Tshuapa': ['Boende', 'Bokungu', 'Ikela'],
  };

  @override
  void initState() {
    super.initState();
    _fetchCountries();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _otherHandicapController.dispose();
    _otherAllergyController.dispose();
    _passwordController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _avenueController.dispose();
    _houseNumberController.dispose();
    _confirmPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCountries() async {
    try {
      final response = await http.get(Uri.parse('https://restcountries.com/v3.1/all?fields=name,flags,idd'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          countries = data.map((country) {
            return {
              'name': country['name']['common'],
              'flag': country['flags']['png'],
              'code': country['idd'] != null && country['idd']['root'] != null 
                  ? (country['idd']['root'] + (country['idd']['suffixes'] != null && country['idd']['suffixes'].isNotEmpty 
                      ? country['idd']['suffixes'][0] : "")) 
                  : null,
            };
          }).toList()..sort((a, b) => a['name'].compareTo(b['name']));

          if (countries.any((country) => country['name'] == rdc)) {
            _selectedCountry = rdc;
            _fetchProvinces(rdc);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching countries: $e');
    }
  }

  Future<void> _fetchProvinces(String countryName) async {
    setState(() {
      _isLoadingProvinces = true;
      _provincesList = [];
      _selectedProvince = null;
      _provinceController.clear();
      _citiesList = [];
      _selectedCity = null;
      _cityController.clear();
    });

    if (countryName == rdc) {
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _provincesList = _rdcProvincesAndCities.keys.toList()..sort();
        _isLoadingProvinces = false;
      });
    } else {
      setState(() => _isLoadingProvinces = false);
    }
  }

  Future<void> _fetchCities(String provinceName) async {
    setState(() {
      _isLoadingCities = true;
      _citiesList = [];
      _selectedCity = null;
      _cityController.clear();
    });

    if (_selectedCountry == rdc && _rdcProvincesAndCities.containsKey(provinceName)) {
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _citiesList = _rdcProvincesAndCities[provinceName]!..sort();
        _isLoadingCities = false;
      });
    } else {
      setState(() => _isLoadingCities = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _registerUser() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un sexe')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      final user = userCredential.user;
      if (user != null) {
        await user.sendEmailVerification();
        setState(() => _isVerificationEmailSent = true);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'country': _selectedCountry,
          'province': _selectedCountry == rdc ? _selectedProvince : _provinceController.text.trim(),
          'city': _selectedCountry == rdc ? _selectedCity : _cityController.text.trim(),
          'district': _districtController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneNumber.phoneNumber,
          'dob': _dobController.text,
          'blood_type': _selectedBloodType,
          'handicap': _selectedHandicap == 'Autre' ? _otherHandicapController.text.trim() : _selectedHandicap,
          'allergies': _selectedAllergy == 'Autre' ? _otherAllergyController.text.trim() : _selectedAllergy,
          'gender': _selectedGender,
          'weight': _weightController.text.trim(),
          'height': _heightController.text.trim(),
          'avenue': _avenueController.text.trim(),
          'house_number': _houseNumberController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        _showVerificationDialog(user);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Erreur d'authentification";
      if (e.code == 'weak-password') errorMessage = 'Mot de passe trop faible';
      else if (e.code == 'email-already-in-use') errorMessage = 'Email déjà utilisé';
      else if (e.code == 'invalid-email') errorMessage = "Email invalide";
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showVerificationDialog(User user) async {
    bool resent = false;
    String? resendError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Vérification de l\'email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Un email de vérification a été envoyé à ${user.email}. Veuillez vérifier votre boîte de réception et cliquer sur le lien pour activer votre compte.. Vérifiez vos spams et marquez-nous comme 'non-spam' si besoin "),
                  if (resent) const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text("Email renvoyé avec succès", style: TextStyle(color: Colors.green)),
                  ),
                  if (resendError != null) Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(resendError!, style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Renvoyer'),
                  onPressed: () async {
                    try {
                      await user.sendEmailVerification();
                      setStateDialog(() {
                        resent = true;
                        resendError = null;
                      });
                    } catch (e) {
                      setStateDialog(() {
                        resent = false;
                        resendError = "Erreur: ${e.toString()}";
                      });
                    }
                  },
                ),
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.textTheme.titleLarge?.color,
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    IconData? icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      style: TextStyle(color: theme.textTheme.bodyMedium?.color),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF4A90E2)) : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant,
      ),
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      readOnly: readOnly,
    );
  }

  Widget _buildDatePickerFormField() {
    final theme = Theme.of(context);
    return _buildTextFormField(
      controller: _dobController,
      labelText: 'Date de naissance',
      icon: Icons.calendar_today,
      readOnly: true,
      validator: (value) => (value == null || value.isEmpty) ? 'Date requise' : null,
      suffixIcon: IconButton(
        icon: Icon(Icons.calendar_month, color: theme.textTheme.bodySmall?.color),
        onPressed: () => _selectDate(context),
      ),
    );
  }

  Widget _buildGenderSelector() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sexe', style: TextStyle(fontSize: 16, color: theme.textTheme.titleMedium?.color)),
        const SizedBox(height: 8),
        Row(
          children: genders.map((gender) {
            bool isSelected = _selectedGender == gender;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedGender = gender),
                child: Container(
                  margin: EdgeInsets.only(right: gender == genders.first ? 8.0 : 0, left: gender == genders.last ? 8.0 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4A90E2) : theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      gender,
                      style: TextStyle(
                        color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_formKey.currentState != null && !_formKey.currentState!.validate() && _selectedGender == null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0),
            child: Text('Le sexe est obligatoire', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: isMobile ? theme.colorScheme.surface : theme.scaffoldBackgroundColor,
      body: isMobile 
        ? SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // Titre
                        Center(
                          child: Text(
                            'Créer un compte',
                            style: TextStyle(
                              fontSize: isDesktop ? 28 : 24,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.headlineMedium?.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section Informations Personnelles
                        _buildSectionTitle('Informations Personnelles'),
                        if (screenWidth > 600)
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextFormField(
                                  controller: _firstNameController,
                                  labelText: 'Prénom',
                                  icon: Icons.person,
                                  validator: (value) => (value == null || value.isEmpty) ? 'Prénom requis' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextFormField(
                                  controller: _lastNameController,
                                  labelText: 'Nom',
                                  icon: Icons.person,
                                  validator: (value) => (value == null || value.isEmpty) ? 'Nom requis' : null,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildTextFormField(
                                controller: _firstNameController,
                                labelText: 'Prénom',
                                icon: Icons.person,
                                validator: (value) => (value == null || value.isEmpty) ? 'Prénom requis' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextFormField(
                                controller: _lastNameController,
                                labelText: 'Nom',
                                icon: Icons.person,
                                validator: (value) => (value == null || value.isEmpty) ? 'Nom requis' : null,
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        _buildDatePickerFormField(),
                        const SizedBox(height: 16),
                        _buildGenderSelector(),
                        const SizedBox(height: 24),

                        // Section Adresse
                        _buildSectionTitle('Adresse'),
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedCountry,
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                            decoration: InputDecoration(
                              labelText: 'Pays',
                              labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                              prefixIcon: Icon(Icons.flag, color: const Color(0xFF4A90E2)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            isExpanded: true,
                            items: countries.map((country) {
                              return DropdownMenuItem<String>(
                                value: country['name'],
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.network(
                                      country['flag'], 
                                      width: 24, 
                                      height: 16,
                                      errorBuilder: (context, error, stackTrace) => 
                                        Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        country['name'],
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: screenWidth > 600 ? 16 : 14),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCountry = value;
                                _fetchProvinces(value!);
                              });
                            },
                            validator: (value) => (value == null) ? 'Pays requis' : null,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_selectedCountry == rdc)
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedProvince,
                              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                              decoration: InputDecoration(
                                labelText: 'Province',
                                labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                prefixIcon: Icon(Icons.location_city, color: const Color(0xFF4A90E2)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceVariant,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              ),
                              isExpanded: true,
                              items: _provincesList.map((province) => 
                                DropdownMenuItem<String>(value: province, child: Text(province))
                              ).toList(),
                              onChanged: _isLoadingProvinces ? null : (value) {
                                setState(() {
                                  _selectedProvince = value;
                                  _fetchCities(value!);
                                });
                              },
                              validator: (value) => (value == null) ? 'Province requise' : null,
                            ),
                          )
                        else
                          _buildTextFormField(
                            controller: _provinceController,
                            labelText: 'Province/État',
                            icon: Icons.location_city,
                            validator: (value) => (value == null || value.isEmpty) ? 'Province requise' : null,
                          ),
                        const SizedBox(height: 16),

                        if (_selectedCountry == rdc)
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedCity,
                              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                              decoration: InputDecoration(
                                labelText: 'Ville/Territoire',
                                labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                prefixIcon: Icon(Icons.location_on, color: const Color(0xFF4A90E2)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceVariant,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              ),
                              isExpanded: true,
                              items: _citiesList.map((city) => 
                                DropdownMenuItem<String>(value: city, child: Text(city))
                              ).toList(),
                              onChanged: _selectedProvince == null || _isLoadingCities ? null : (value) {
                                setState(() => _selectedCity = value);
                              },
                              validator: (value) => (_selectedCountry == rdc && _selectedProvince != null && value == null) 
                                  ? 'Ville requise' : null,
                            ),
                          )
                        else
                          _buildTextFormField(
                            controller: _cityController,
                            labelText: 'Ville',
                            icon: Icons.location_on,
                            validator: (value) => (value == null || value.isEmpty) ? 'Ville requise' : null,
                          ),
                        const SizedBox(height: 16),

                        _buildTextFormField(
                          controller: _districtController,
                          labelText: 'Quartier/Commune',
                          icon: Icons.home,
                          validator: (value) => (value == null || value.isEmpty) ? 'Quartier requis' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildTextFormField(
                          controller: _avenueController,
                          labelText: 'Avenue/Rue',
                          icon: Icons.streetview,
                          validator: (value) => (value == null || value.isEmpty) ? 'Avenue requise' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildTextFormField(
                          controller: _houseNumberController,
                          labelText: 'Numéro de maison',
                          icon: Icons.format_list_numbered,
                          keyboardType: TextInputType.number,
                          validator: (value) => (value == null || value.isEmpty) ? 'Numéro requis' : null,
                        ),
                        const SizedBox(height: 24),

                        // Section Contact
                        _buildSectionTitle('Contact'),
                        _buildTextFormField(
                          controller: _emailController,
                          labelText: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Email requis';
                            if (!value.contains('@') || !value.contains('.')) return 'Email invalide';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        InternationalPhoneNumberInput(
                          onInputChanged: (PhoneNumber number) => _phoneNumber = number,
                          selectorConfig: const SelectorConfig(
                            selectorType: PhoneInputSelectorType.DIALOG,
                          ),
                          ignoreBlank: false,
                          initialValue: _phoneNumber,
                          textFieldController: _phoneController,
                          inputDecoration: InputDecoration(
                            labelText: 'Téléphone',
                            labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                            prefixIcon: Icon(Icons.phone, color: const Color(0xFF4A90E2)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceVariant,
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'Téléphone requis' : null,
                          spaceBetweenSelectorAndTextField: 0,
                          selectorButtonOnErrorPadding: 0,
                          textAlign: TextAlign.left,
                          textAlignVertical: TextAlignVertical.center,
                          formatInput: true,
                          autoValidateMode: AutovalidateMode.disabled,
                        ),
                        const SizedBox(height: 24),

                        // Section Informations Médicales
                        _buildSectionTitle('Informations Médicales'),
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedBloodType,
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                            decoration: InputDecoration(
                              labelText: 'Groupe sanguin',
                              labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                              prefixIcon: Icon(Icons.bloodtype, color: const Color(0xFF4A90E2)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            isExpanded: true,
                            items: bloodTypes.map((type) => 
                              DropdownMenuItem<String>(value: type, child: Text(type))
                            ).toList(),
                            onChanged: (value) => setState(() => _selectedBloodType = value),
                            validator: (value) => (value == null) ? 'Groupe sanguin requis' : null,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Container(
                          constraints: BoxConstraints(
                            maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedHandicap,
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                            decoration: InputDecoration(
                              labelText: 'Handicap',
                              labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                              prefixIcon: Icon(Icons.accessible, color: const Color(0xFF4A90E2)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            isExpanded: true,
                            items: disabilities.map((disability) => 
                              DropdownMenuItem<String>(value: disability, child: Text(disability))
                            ).toList(),
                            onChanged: (value) => setState(() => _selectedHandicap = value),
                            validator: (value) => (value == null) ? 'Champ requis' : null,
                          ),
                        ),
                        if (_selectedHandicap == 'Autre') ...[
                          const SizedBox(height: 16),
                          _buildTextFormField(
                            controller: _otherHandicapController,
                            labelText: 'Précisez le handicap',
                            icon: Icons.edit,
                            validator: (value) => (value == null || value.isEmpty) ? 'Précision requise' : null,
                          ),
                        ],
                        const SizedBox(height: 16),

                        Container(
                          constraints: BoxConstraints(
                            maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedAllergy,
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                            decoration: InputDecoration(
                              labelText: 'Allergies',
                              labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                              prefixIcon: Icon(Icons.warning, color: const Color(0xFF4A90E2)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            isExpanded: true,
                            items: allergiesList.map((allergy) => 
                              DropdownMenuItem<String>(value: allergy, child: Text(allergy))
                            ).toList(),
                            onChanged: (value) => setState(() => _selectedAllergy = value),
                            validator: (value) => (value == null) ? 'Champ requis' : null,
                          ),
                        ),
                        if (_selectedAllergy == 'Autre') ...[
                          const SizedBox(height: 16),
                          _buildTextFormField(
                            controller: _otherAllergyController,
                            labelText: 'Précisez l\'allergie',
                            icon: Icons.edit,
                            validator: (value) => (value == null || value.isEmpty) ? 'Précision requise' : null,
                          ),
                        ],
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                controller: _weightController,
                                labelText: 'Poids (kg)',
                                icon: Icons.monitor_weight,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextFormField(
                                controller: _heightController,
                                labelText: 'Taille (cm)',
                                icon: Icons.height,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Section Sécurité
                        _buildSectionTitle('Sécurité du compte'),
                        _buildTextFormField(
                          controller: _passwordController,
                          labelText: 'Mot de passe',
                          icon: Icons.lock,
                          obscureText: !_isPasswordVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Mot de passe requis';
                            if (value.length < 6) return 'Minimum 6 caractères';
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildTextFormField(
                          controller: _confirmPasswordController,
                          labelText: 'Confirmer le mot de passe',
                          icon: Icons.lock,
                          obscureText: !_isConfirmPasswordVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Confirmation requise';
                            if (value != _passwordController.text) return 'Mots de passe différents';
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                            onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Bouton de soumission
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _registerUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? CircularProgressIndicator(color: theme.colorScheme.onPrimary)
                                : Text(
                                    'Créer un compte',
                                    style: TextStyle(fontSize: 18, color: theme.colorScheme.onPrimary),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            )
        : Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth > 600 ? 20.0 : 10.0),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 700 : (screenWidth > 600 ? screenWidth * 0.9 : screenWidth * 0.95),
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isDesktop ? 40.0 : (screenWidth > 600 ? 20.0 : 15.0)),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Titre
                            Center(
                              child: Text(
                                'Créer un compte',
                                style: TextStyle(
                                  fontSize: isDesktop ? 28 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.headlineMedium?.color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Section Informations Personnelles
                            _buildSectionTitle('Informations Personnelles'),
                            if (screenWidth > 600)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextFormField(
                                      controller: _firstNameController,
                                      labelText: 'Prénom',
                                      icon: Icons.person,
                                      validator: (value) => (value == null || value.isEmpty) ? 'Prénom requis' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTextFormField(
                                      controller: _lastNameController,
                                      labelText: 'Nom',
                                      icon: Icons.person,
                                      validator: (value) => (value == null || value.isEmpty) ? 'Nom requis' : null,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  _buildTextFormField(
                                    controller: _firstNameController,
                                    labelText: 'Prénom',
                                    icon: Icons.person,
                                    validator: (value) => (value == null || value.isEmpty) ? 'Prénom requis' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextFormField(
                                    controller: _lastNameController,
                                    labelText: 'Nom',
                                    icon: Icons.person,
                                    validator: (value) => (value == null || value.isEmpty) ? 'Nom requis' : null,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            _buildDatePickerFormField(),
                            const SizedBox(height: 16),
                            _buildGenderSelector(),
                            const SizedBox(height: 24),

                            // Section Adresse
                            _buildSectionTitle('Adresse'),
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedCountry,
                                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                decoration: InputDecoration(
                                  labelText: 'Pays',
                                  labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                  prefixIcon: Icon(Icons.flag, color: const Color(0xFF4A90E2)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceVariant,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                isExpanded: true,
                                items: countries.map((country) {
                                  return DropdownMenuItem<String>(
                                    value: country['name'],
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.network(
                                          country['flag'], 
                                          width: 24, 
                                          height: 16,
                                          errorBuilder: (context, error, stackTrace) => 
                                            Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            country['name'],
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: screenWidth > 600 ? 16 : 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCountry = value;
                                    _fetchProvinces(value!);
                                  });
                                },
                                validator: (value) => (value == null) ? 'Pays requis' : null,
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_selectedCountry == rdc)
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedProvince,
                                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                  decoration: InputDecoration(
                                    labelText: 'Province',
                                    labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                    prefixIcon: Icon(Icons.location_city, color: const Color(0xFF4A90E2)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: theme.colorScheme.surfaceVariant,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                  isExpanded: true,
                                  items: _provincesList.map((province) => 
                                    DropdownMenuItem<String>(value: province, child: Text(province))
                                  ).toList(),
                                  onChanged: _isLoadingProvinces ? null : (value) {
                                    setState(() {
                                      _selectedProvince = value;
                                      _fetchCities(value!);
                                    });
                                  },
                                  validator: (value) => (value == null) ? 'Province requise' : null,
                                ),
                              )
                            else
                              _buildTextFormField(
                                controller: _provinceController,
                                labelText: 'Province/État',
                                icon: Icons.location_city,
                                validator: (value) => (value == null || value.isEmpty) ? 'Province requise' : null,
                              ),
                            const SizedBox(height: 16),

                            if (_selectedCountry == rdc)
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCity,
                                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                  decoration: InputDecoration(
                                    labelText: 'Ville/Territoire',
                                    labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                    prefixIcon: Icon(Icons.location_on, color: const Color(0xFF4A90E2)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: theme.colorScheme.surfaceVariant,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                  isExpanded: true,
                                  items: _citiesList.map((city) => 
                                    DropdownMenuItem<String>(value: city, child: Text(city))
                                  ).toList(),
                                  onChanged: _selectedProvince == null || _isLoadingCities ? null : (value) {
                                    setState(() => _selectedCity = value);
                                  },
                                  validator: (value) => (_selectedCountry == rdc && _selectedProvince != null && value == null) 
                                      ? 'Ville requise' : null,
                                ),
                              )
                            else
                              _buildTextFormField(
                                controller: _cityController,
                                labelText: 'Ville',
                                icon: Icons.location_on,
                                validator: (value) => (value == null || value.isEmpty) ? 'Ville requise' : null,
                              ),
                            const SizedBox(height: 16),

                            _buildTextFormField(
                              controller: _districtController,
                              labelText: 'Quartier/Commune',
                              icon: Icons.home,
                              validator: (value) => (value == null || value.isEmpty) ? 'Quartier requis' : null,
                            ),
                            const SizedBox(height: 16),

                            _buildTextFormField(
                              controller: _avenueController,
                              labelText: 'Avenue/Rue',
                              icon: Icons.streetview,
                              validator: (value) => (value == null || value.isEmpty) ? 'Avenue requise' : null,
                            ),
                            const SizedBox(height: 16),

                            _buildTextFormField(
                              controller: _houseNumberController,
                              labelText: 'Numéro de maison',
                              icon: Icons.format_list_numbered,
                              keyboardType: TextInputType.number,
                              validator: (value) => (value == null || value.isEmpty) ? 'Numéro requis' : null,
                            ),
                            const SizedBox(height: 24),

                            // Section Contact
                            _buildSectionTitle('Contact'),
                            _buildTextFormField(
                              controller: _emailController,
                              labelText: 'Email',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Email requis';
                                if (!value.contains('@') || !value.contains('.')) return 'Email invalide';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            InternationalPhoneNumberInput(
                              onInputChanged: (PhoneNumber number) => _phoneNumber = number,
                              selectorConfig: const SelectorConfig(
                                selectorType: PhoneInputSelectorType.DIALOG,
                              ),
                              ignoreBlank: false,
                              initialValue: _phoneNumber,
                              textFieldController: _phoneController,
                              inputDecoration: InputDecoration(
                                labelText: 'Téléphone',
                                labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                prefixIcon: Icon(Icons.phone, color: const Color(0xFF4A90E2)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceVariant,
                              ),
                              validator: (value) => (value == null || value.isEmpty) ? 'Téléphone requis' : null,
                              spaceBetweenSelectorAndTextField: 0,
                              selectorButtonOnErrorPadding: 0,
                              textAlign: TextAlign.left,
                              textAlignVertical: TextAlignVertical.center,
                              formatInput: true,
                              autoValidateMode: AutovalidateMode.disabled,
                            ),
                            const SizedBox(height: 24),

                            // Section Informations Médicales
                            _buildSectionTitle('Informations Médicales'),
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedBloodType,
                                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                decoration: InputDecoration(
                                  labelText: 'Groupe sanguin',
                                  labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                  prefixIcon: Icon(Icons.bloodtype, color: const Color(0xFF4A90E2)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceVariant,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                isExpanded: true,
                                items: bloodTypes.map((type) => 
                                  DropdownMenuItem<String>(value: type, child: Text(type))
                                ).toList(),
                                onChanged: (value) => setState(() => _selectedBloodType = value),
                                validator: (value) => (value == null) ? 'Groupe sanguin requis' : null,
                              ),
                            ),
                            const SizedBox(height: 16),

                            Container(
                              constraints: BoxConstraints(
                                maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedHandicap,
                                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                decoration: InputDecoration(
                                  labelText: 'Handicap',
                                  labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                  prefixIcon: Icon(Icons.accessible, color: const Color(0xFF4A90E2)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceVariant,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                isExpanded: true,
                                items: disabilities.map((disability) => 
                                  DropdownMenuItem<String>(value: disability, child: Text(disability))
                                ).toList(),
                                onChanged: (value) => setState(() => _selectedHandicap = value),
                                validator: (value) => (value == null) ? 'Champ requis' : null,
                              ),
                            ),
                            if (_selectedHandicap == 'Autre') ...[
                              const SizedBox(height: 16),
                              _buildTextFormField(
                                controller: _otherHandicapController,
                                labelText: 'Précisez le handicap',
                                icon: Icons.edit,
                                validator: (value) => (value == null || value.isEmpty) ? 'Précision requise' : null,
                              ),
                            ],
                            const SizedBox(height: 16),

                            Container(
                              constraints: BoxConstraints(
                                maxWidth: screenWidth > 600 ? double.infinity : screenWidth * 0.85,
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedAllergy,
                                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                decoration: InputDecoration(
                                  labelText: 'Allergies',
                                  labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                  prefixIcon: Icon(Icons.warning, color: const Color(0xFF4A90E2)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceVariant,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                isExpanded: true,
                                items: allergiesList.map((allergy) => 
                                  DropdownMenuItem<String>(value: allergy, child: Text(allergy))
                                ).toList(),
                                onChanged: (value) => setState(() => _selectedAllergy = value),
                                validator: (value) => (value == null) ? 'Champ requis' : null,
                              ),
                            ),
                            if (_selectedAllergy == 'Autre') ...[
                              const SizedBox(height: 16),
                              _buildTextFormField(
                                controller: _otherAllergyController,
                                labelText: 'Précisez l\'allergie',
                                icon: Icons.edit,
                                validator: (value) => (value == null || value.isEmpty) ? 'Précision requise' : null,
                              ),
                            ],
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _weightController,
                                    labelText: 'Poids (kg)',
                                    icon: Icons.monitor_weight,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _heightController,
                                    labelText: 'Taille (cm)',
                                    icon: Icons.height,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Section Sécurité
                            _buildSectionTitle('Sécurité du compte'),
                            _buildTextFormField(
                              controller: _passwordController,
                              labelText: 'Mot de passe',
                              icon: Icons.lock,
                              obscureText: !_isPasswordVisible,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Mot de passe requis';
                                if (value.length < 6) return 'Minimum 6 caractères';
                                return null;
                              },
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildTextFormField(
                              controller: _confirmPasswordController,
                              labelText: 'Confirmer le mot de passe',
                              icon: Icons.lock,
                              obscureText: !_isConfirmPasswordVisible,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Confirmation requise';
                                if (value != _passwordController.text) return 'Mots de passe différents';
                                return null;
                              },
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                                onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Bouton de soumission
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _registerUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A90E2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isLoading
                                    ? CircularProgressIndicator(color: theme.colorScheme.onPrimary)
                                    : Text(
                                        'Créer un compte',
                                        style: TextStyle(fontSize: 18, color: theme.colorScheme.onPrimary),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
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
}