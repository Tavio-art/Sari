import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../widgets/product_image.dart';

/// Standalone edit-profile page — opened from Profile (not embedded in Settings).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _storeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  static final DateFormat _displayFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _storageFormat = DateFormat('yyyy-MM-dd');

  String _photoDataUrl = '';
  Uint8List? _photoBytes;
  DateTime? _birthDate;
  bool _loading = true;
  bool _saving = false;

  /// Firestore docs are limited to ~1MB; keep raw picks under this so the
  /// base64 `data:` URL (~4/3 size) still fits with other profile fields.
  static const int _maxPhotoBytes = 500 * 1024;
  static const int _maxUsernameLength = 24;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _storeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    _emailController.text = user.email ?? '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      _firstNameController.text = (data['firstName'] ?? '').toString();
      _lastNameController.text = (data['lastName'] ?? '').toString();
      _usernameController.text = (data['username'] ?? '').toString();
      _storeController.text = (data['storeName'] ?? '').toString();
      _addressController.text = (data['address'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();
      final storedEmail = (data['email'] ?? '').toString().trim();
      if (storedEmail.isNotEmpty) {
        _emailController.text = storedEmail;
      }

      final dobRaw = (data['dateOfBirth'] ?? '').toString().trim();
      if (dobRaw.isNotEmpty) {
        _birthDate = DateTime.tryParse(dobRaw) ??
            (dobRaw.contains('/')
                ? null
                : DateTime.tryParse(dobRaw.replaceAll('/', '-')));
      }

      final photo = (data['photoUrl'] ?? '').toString();
      if (photo.isNotEmpty) {
        _photoDataUrl = photo;
        if (photo.startsWith('data:image')) {
          try {
            _photoBytes = base64Decode(photo.split(',').last);
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.darkGreenMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textFaint.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library,
                    color: AppColors.mintIcon),
                title: const Text('Gallery',
                    style: TextStyle(color: AppColors.textWhite)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading:
                    const Icon(Icons.camera_alt, color: AppColors.mintIcon),
                title: const Text('Camera',
                    style: TextStyle(color: AppColors.textWhite)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              if (_photoDataUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: AppColors.accentRed),
                  title: const Text('Remove photo',
                      style: TextStyle(color: AppColors.accentRed)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _photoBytes = null;
                      _photoDataUrl = '';
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 55,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > _maxPhotoBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Photo is too large. Pick a smaller image or crop closer.',
            ),
            backgroundColor: AppColors.accentRed,
          ),
        );
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoDataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick photo: $e'),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - 13, now.month, now.day);
    final earliest = DateTime(now.year - 100, now.month, now.day);
    final initial =
        _birthDate ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(earliest)
          ? earliest
          : (initial.isAfter(latest) ? latest : initial),
      firstDate: earliest,
      lastDate: latest,
      helpText: 'Select your birthday',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentOrange,
              onPrimary: AppColors.darkGreenTop,
              surface: AppColors.darkGreenMid,
              onSurface: AppColors.textWhite,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.darkGreenMid,
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

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!ok) return 'Enter a valid email address';
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    final username = (value ?? '').trim();
    if (username.isEmpty) return null; // optional
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (username.length > _maxUsernameLength) {
      return 'Username is too long';
    }
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
      return 'Use letters, numbers, dots, or underscores only';
    }
    return null;
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No signed-in user. Please log in again.'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final storeName = _storeController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();

    const maxEncodedChars = 900 * 1024;
    if (_photoDataUrl.startsWith('data:image') &&
        _photoDataUrl.length > maxEncodedChars) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile photo is too large to save. Choose a smaller image.',
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'storeName': storeName,
        'email': email,
        'address': address,
        'phone': phone,
        'photoUrl': _photoDataUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_birthDate != null) {
        payload['dateOfBirth'] = _storageFormat.format(_birthDate!);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      String successMessage = 'Profile saved.';

      if (user.email != null &&
          user.email!.toLowerCase() != email.toLowerCase()) {
        try {
          await user.verifyBeforeUpdateEmail(email);
          successMessage =
              'Profile saved. Check your inbox to confirm the new email.';
        } catch (e) {
          debugPrint('Auth email update skipped: $e');
          successMessage =
              'Profile saved. Email login was not changed (re-login may be required to update it).';
        }
      }

      final display = '$firstName $lastName'.trim();
      if (display.isNotEmpty) {
        try {
          await user.updateDisplayName(display);
        } catch (e) {
          debugPrint('Display name update skipped: $e');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppColors.mediumGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppColors.accentRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.mintIcon),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: AppColors.textWhite),
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(false),
                          ),
                          const Expanded(
                            child: Text(
                              'Edit Profile',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _saving ? null : _save,
                            child: Text(
                              'Save',
                              style: TextStyle(
                                color: _saving
                                    ? AppColors.textFaint
                                    : AppColors.accentOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            8,
                            20,
                            24 + bottomInset,
                          ),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: [
                            Center(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _saving ? null : _pickPhoto,
                                  customBorder: const CircleBorder(),
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      CircleAvatar(
                                        radius: 52,
                                        backgroundColor: AppColors.fieldGreen,
                                        backgroundImage: _photoBytes != null
                                            ? MemoryImage(_photoBytes!)
                                            : null,
                                        child: _photoBytes == null
                                            ? (_photoDataUrl.isNotEmpty
                                                ? ClipOval(
                                                    child: ProductImage(
                                                      imageUrl: _photoDataUrl,
                                                      width: 104,
                                                      height: 104,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : const Icon(Icons.person,
                                                    size: 44,
                                                    color:
                                                        AppColors.textWhite))
                                            : null,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentOrange,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.darkGreenTop,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(Icons.camera_alt,
                                            size: 16,
                                            color: AppColors.darkGreenTop),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Center(
                              child: Text(
                                'Tap to change profile picture',
                                style: TextStyle(
                                  color: AppColors.textFaint,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _sectionLabel('PERSONAL'),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _field(
                                    'First name',
                                    _firstNameController,
                                    validator: (v) =>
                                        _required(v, 'First name'),
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _field(
                                    'Last name',
                                    _lastNameController,
                                    validator: (v) =>
                                        _required(v, 'Last name'),
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                ),
                              ],
                            ),
                            _field(
                              'Username',
                              _usernameController,
                              hint: 'optional · letters, numbers, ._ ',
                              validator: _validateUsername,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9._]'),
                                ),
                                LengthLimitingTextInputFormatter(
                                  _maxUsernameLength,
                                ),
                              ],
                            ),
                            _birthdayField(),
                            const SizedBox(height: 8),
                            _sectionLabel('STORE & CONTACT'),
                            _field(
                              'Store name',
                              _storeController,
                              validator: (v) => _required(v, 'Store name'),
                              textCapitalization: TextCapitalization.words,
                            ),
                            _field(
                              'Email',
                              _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                            _field(
                              'Phone',
                              _phoneController,
                              keyboardType: TextInputType.phone,
                              hint: 'optional',
                              validator: _validatePhone,
                            ),
                            _field(
                              'Address',
                              _addressController,
                              maxLines: 2,
                              validator: (v) => _required(v, 'Address'),
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentOrange,
                                  foregroundColor: AppColors.darkGreenTop,
                                  disabledBackgroundColor: AppColors
                                      .accentOrange
                                      .withValues(alpha: 0.45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.darkGreenTop,
                                        ),
                                      )
                                    : const Text(
                                        'Save Profile',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: TextButton(
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textMuted,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(
                                      color: AppColors.mintIcon
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
          ),
        ),
      );

  Widget _birthdayField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saving ? null : _pickBirthDate,
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Birthday',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.fieldGreen.withValues(alpha: 0.45),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              suffixIcon: const Icon(Icons.calendar_today_outlined,
                  color: AppColors.textFaint, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.mintIcon.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Text(
              _birthDate != null
                  ? _displayFormat.format(_birthDate!)
                  : 'Select your birthday',
              style: TextStyle(
                color: _birthDate != null
                    ? AppColors.textWhite
                    : AppColors.textFaint,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        enabled: !_saving,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: AppColors.textWhite),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: AppColors.textMuted),
          hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 13),
          errorStyle: const TextStyle(color: AppColors.accentOrange),
          filled: true,
          fillColor: AppColors.fieldGreen.withValues(alpha: 0.45),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.mintIcon.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.accentOrange,
              width: 1.2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.accentRed),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.accentRed, width: 1.2),
          ),
        ),
      ),
    );
  }
}
