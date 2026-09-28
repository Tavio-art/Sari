import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _birthDate;
  bool _isLoading = false;

  static final DateFormat _displayFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _storageFormat = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _storeNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    // Require at least 13 years old; allow up to 100 years old.
    final latest = DateTime(now.year - 13, now.month, now.day);
    final earliest = DateTime(now.year - 100, now.month, now.day);
    final initial = _birthDate ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(earliest)
          ? earliest
          : (initial.isAfter(latest) ? latest : initial),
      firstDate: earliest,
      lastDate: latest,
      helpText: 'Select your birthday',
      cancelText: 'Cancel',
      confirmText: 'Done',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF2AD43),
              onPrimary: Color(0xFF1D2E24),
              surface: Color(0xFF1E4433),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E4433),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  bool _isValidBirthDate(DateTime date) {
    final now = DateTime.now();
    final thirteenYearsAgo = DateTime(now.year - 13, now.month, now.day);
    final hundredYearsAgo = DateTime(now.year - 100, now.month, now.day);
    return !date.isAfter(thirteenYearsAgo) && !date.isBefore(hundredYearsAgo);
  }

  Future<void> _signUp() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final storeName = _storeNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Basic Validations
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        storeName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _birthDate == null) {
      _showSnackBar('Please fill in all fields.', isError: true);
      return;
    }

    if (!_isValidBirthDate(_birthDate!)) {
      _showSnackBar(
        'Please select a valid birthday (you must be at least 13 years old).',
        isError: true,
      );
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match.', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid;
      final dobIso = _storageFormat.format(_birthDate!);

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'firstName': firstName,
        'lastName': lastName,
        'storeName': storeName,
        'email': email,
        'dateOfBirth': dobIso,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      _showSnackBar('Account created successfully! Please log in.',
          isError: false);

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'An error occurred during registration.',
          isError: true);
    } catch (e) {
      _showSnackBar('Failed to sign up: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Widget _balancedTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 46,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFF80A391), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF0F2B20).withValues(alpha: 0.8),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _birthdayPickerField() {
    final hasDate = _birthDate != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _pickBirthDate,
            borderRadius: BorderRadius.circular(26),
            child: Ink(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0F2B20).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasDate
                            ? _displayFormat.format(_birthDate!)
                            : 'Select your birthday',
                        style: TextStyle(
                          color: hasDate
                              ? Colors.white
                              : const Color(0xFF80A391),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFFF2AD43),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C241B),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Container(color: const Color(0xFF0C241B)),
          Positioned.fill(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: const Color(0xFF0C241B));
              },
            ),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      const Text(
                        'Sign up',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF264C39).withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _balancedTextField(
                              label: 'First Name',
                              hint: 'Enter your first name',
                              controller: _firstNameController,
                            ),
                            const SizedBox(height: 10),
                            _balancedTextField(
                              label: 'Last Name',
                              hint: 'Enter your last name',
                              controller: _lastNameController,
                            ),
                            const SizedBox(height: 10),
                            _balancedTextField(
                              label: 'Name of the Store',
                              hint: 'Enter store name',
                              controller: _storeNameController,
                            ),
                            const SizedBox(height: 10),
                            _balancedTextField(
                              label: 'Email',
                              hint: 'Enter your email',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 10),
                            _balancedTextField(
                              label: 'Password',
                              hint: 'Enter your password',
                              controller: _passwordController,
                              obscureText: true,
                            ),
                            const SizedBox(height: 10),
                            _balancedTextField(
                              label: 'Confirm Password',
                              hint: 'Re-enter your password',
                              controller: _confirmPasswordController,
                              obscureText: true,
                            ),
                            const SizedBox(height: 10),
                            _birthdayPickerField(),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF2AD43),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF1D2E24),
                                        ),
                                      )
                                    : const Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          color: Color(0xFF1D2E24),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: Color(0xFFD0E0D5),
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            color: Color(0xFFF2AD43),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
