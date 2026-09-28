import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_image.dart';
import '../dashboard/dashboard_section.dart';
import '../orders/orders_screen.dart';
import '../settings/settings_screen.dart';
import '../credit/credit_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userName;
  final ValueChanged<String>? onNameChanged;

  const ProfileScreen({
    super.key,
    this.userName,
    this.onNameChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _username = '';
  String _storeName = '';
  String _address = '';
  String _email = '';
  String _phone = '';
  String _photoUrl = '';
  Uint8List? _imageBytes;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final firstName = (data['firstName'] ?? '').toString();
          final lastName = (data['lastName'] ?? '').toString();
          final fullName = '$firstName $lastName'.trim();
          final photo = (data['photoUrl'] ?? '').toString();
          Uint8List? bytes;
          if (photo.startsWith('data:image')) {
            try {
              bytes = base64Decode(photo.split(',').last);
            } catch (_) {}
          }

          if (!mounted) return;
          setState(() {
            _name =
                fullName.isNotEmpty ? fullName : (widget.userName ?? 'User');
            _username = (data['username'] ?? '').toString().trim();
            _storeName = (data['storeName'] ?? '').toString().trim().isNotEmpty
                ? (data['storeName'] ?? 'My Store').toString()
                : 'My Store';
            _address = (data['address'] ?? '').toString();
            _email = (data['email'] ?? user.email ?? '').toString();
            _phone = (data['phone'] ?? '').toString();
            _photoUrl = photo;
            _imageBytes = bytes;
            _loading = false;
          });
          return;
        }
      } catch (e) {
        if (!mounted) return;
        _setFallbackData();
        setState(() {
          _loadError = context.l10n.text('profileLoadError');
          _loading = false;
        });
        return;
      }
    }
    _setFallbackData();
    if (mounted) setState(() => _loading = false);
  }

  void _setFallbackData() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _name = (widget.userName != null && widget.userName!.isNotEmpty)
          ? widget.userName!
          : (user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!
              : 'User');
      _username = '';
      _storeName = 'My Store';
      _email = user?.email ?? '';
      _phone = '';
      _address = '';
    });
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (updated == true && mounted) {
      await _fetchUserData();
      if (widget.onNameChanged != null) {
        widget.onNameChanged!(_name);
      }
    }
  }

  Widget _avatar({double radius = 40}) {
    Widget avatar;
    if (_imageBytes != null) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.mintIcon,
        backgroundImage: MemoryImage(_imageBytes!),
      );
    } else if (_photoUrl.isNotEmpty && !_photoUrl.startsWith('data:image')) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.mintIcon,
        child: ClipOval(
          child: ProductImage(
            imageUrl: _photoUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.mintIcon,
        child: Text(
          _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
          style: TextStyle(
            color: AppColors.darkGreenTop,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.7,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loading ? null : _openEditProfile,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.mintIcon.withValues(alpha: 0.45),
                  width: 2.5,
                ),
              ),
              child: avatar,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.darkGreenMid,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 12,
                  color: AppColors.darkGreenTop,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 360 ? 14.0 : 20.0;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.darkGreenTop,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.accentOrange,
            backgroundColor: AppColors.darkGreenMid,
            onRefresh: _fetchUserData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                    child: Text(
                      l10n.text('profileTitle'),
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (_loadError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.accentOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.accentOrange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _loadError!,
                        style: const TextStyle(
                          color: AppColors.accentOrange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],

                  // ── Identity header (name, username, email, store — all
                  // together at the top) ──────────────────────────────────
                  _glassCard(
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.mintIcon,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _avatar(),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _name,
                                          style: const TextStyle(
                                            color: AppColors.textWhite,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            height: 1.2,
                                          ),
                                        ),
                                        if (_username.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '@$_username',
                                            style: const TextStyle(
                                              color: AppColors.accentOrange,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        if (_email.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          _headerInfoRow(
                                            Icons.email_outlined,
                                            _email,
                                          ),
                                        ],
                                        if (_storeName.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          _headerInfoRow(
                                            Icons.storefront_outlined,
                                            _storeName,
                                          ),
                                        ],
                                        if (_phone.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          _headerInfoRow(
                                            Icons.phone_outlined,
                                            _phone,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _openEditProfile,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: AppColors.accentOrange,
                                            width: 1.3,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.edit_outlined,
                                              size: 15,
                                              color: AppColors.accentOrange,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              l10n.text('edit'),
                                              style: const TextStyle(
                                                color: AppColors.accentOrange,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_address.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _headerInfoRow(
                                  Icons.location_on_outlined,
                                  _address,
                                ),
                              ],
                            ],
                          ),
                  ),

                  if (!_loading) ...[
                    const DashboardSection(),
                  ],

                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      l10n.text('manage'),
                      style: const TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _menuTile(
                    Icons.receipt_long_rounded,
                    l10n.text('orders'),
                    l10n.text('ordersSubtitle'),
                    const OrdersScreen(),
                  ),
                  _menuTile(
                    Icons.assignment_outlined,
                    l10n.text('creditUtang'),
                    l10n.text('creditUtangSubtitle'),
                    const CreditScreen(),
                  ),
                  _menuTile(
                    Icons.settings_outlined,
                    l10n.text('settings'),
                    l10n.text('settingsMenuSubtitle'),
                    const SettingsScreen(),
                  ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 18, 16, 18),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.darkGreenMid.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _headerInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppColors.textFaint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textFaint,
              fontSize: 12,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _menuTile(
    IconData icon,
    String title,
    String subtitle,
    Widget destination,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => destination),
            );
            if (mounted) await _fetchUserData();
          },
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.darkGreenMid.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1,
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.mintIcon.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.mintIcon, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.accentOrange,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}