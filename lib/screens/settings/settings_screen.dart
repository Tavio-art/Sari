import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../services/push_notification_service.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsStore _settings = SettingsStore.instance;
  bool _pushBusy = false;

  @override
  void initState() {
    super.initState();
    _syncPushWithOs();
  }

  /// If OS permission was revoked, reflect that in the Settings toggle.
  Future<void> _syncPushWithOs() async {
    try {
      final granted =
          await PushNotificationService.instance.isOsPermissionGranted;
      if (!granted && _settings.pushEnabled) {
        await _settings.setPush(false);
      }
    } catch (_) {}
  }

  Future<void> _pickLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.darkGreenMid,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.mintIcon.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.textFaint.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  l10n.text('selectLanguage'),
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                for (final code in const ['en', 'fil'])
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, code),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.languageName(code),
                                style: const TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (code == _settings.languageCode)
                              const Icon(
                                Icons.check_rounded,
                                color: AppColors.accentOrange,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) await _settings.setLanguage(selected);
  }

  Future<void> _pickCurrency() async {
    final l10n = context.l10n;
    const options = ['PHP', 'USD', 'EUR', 'JPY'];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.darkGreenMid,
        title: Text(
          l10n.text('selectCurrency'),
          style: const TextStyle(color: AppColors.textWhite),
        ),
        children: options
            .map(
              (code) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, code),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        style: const TextStyle(color: AppColors.textWhite),
                      ),
                    ),
                    if (code == _settings.currencyCode)
                      const Icon(Icons.check, color: AppColors.accentOrange),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      await _settings.setCurrency(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.text(
                'currencySet',
                values: {'currency': _settings.currencyLabel},
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _editExchangeRate() async {
    final l10n = context.l10n;
    if (_settings.currencyCode == 'PHP') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.text('phpExchangeRate'))),
      );
      return;
    }
    final controller = TextEditingController(
      text: _settings.exchangeRate.toString(),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkGreenMid,
        title: Text(
          l10n.text(
            'exchangeRateTitle',
            values: {'currency': _settings.currencyCode},
          ),
          style: const TextStyle(color: AppColors.textWhite, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            labelText: l10n.text(
              'exchangeRatePrompt',
              values: {'currency': _settings.currencyCode},
            ),
            hintText:
                SettingsStore.defaultRateFor(_settings.currencyCode).toString(),
            labelStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.fieldGreen.withValues(alpha: 0.35),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.text('cancel'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.text('validRate'))),
                );
                return;
              }
              Navigator.pop(ctx, value);
            },
            child: Text(l10n.text('save')),
          ),
        ],
      ),
    );
    if (result != null) {
      await _settings.setExchangeRate(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.text(
                'rateSaved',
                values: {
                  'rate': _settings.exchangeRate.toString(),
                  'currency': _settings.currencyCode,
                },
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _editTaxRate() async {
    final l10n = context.l10n;
    final controller =
        TextEditingController(text: _settings.taxRate.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkGreenMid,
        title: Text(
          l10n.text('taxRateTitle'),
          style: const TextStyle(color: AppColors.textWhite),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            labelText: l10n.text('percent'),
            suffixText: '%',
            labelStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.fieldGreen.withValues(alpha: 0.35),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.text('cancel'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value < 0 || value > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.text('validTaxRate'))),
                );
                return;
              }
              Navigator.pop(ctx, value);
            },
            child: Text(l10n.text('save')),
          ),
        ],
      ),
    );
    if (result != null) {
      await _settings.setTaxRate(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.text(
                'taxRateSet',
                values: {'rate': _settings.taxRate.toStringAsFixed(0)},
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _onPushChanged(bool enable) async {
    final l10n = context.l10n;
    if (_pushBusy) return;
    setState(() => _pushBusy = true);
    try {
      if (enable) {
        final granted =
            await PushNotificationService.instance.enableFromSettings();
        if (!mounted) return;
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.text('pushPermissionOff')),
              action: SnackBarAction(
                label: l10n.text('open'),
                textColor: AppColors.accentOrange,
                onPressed: () {
                  PushNotificationService.instance.openSystemSettings();
                },
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.text('pushEnabled'))),
          );
        }
      } else {
        await PushNotificationService.instance.disableFromSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.text('pushDisabled'))),
        );
      }
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  Future<void> _logout() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkGreenMid,
        title: Text(
          l10n.text('logOutTitle'),
          style: const TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          l10n.text('logOutMessage'),
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.text('cancel'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.text('logOut')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textWhite),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        context.l10n.text('settings'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _settings,
                    builder: (context, _) {
                      final l10n = context.l10n;
                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _sectionLabel(l10n.text('languageSection')),
                          _tileCard(
                            children: [
                              _navRow(
                                l10n.text('language'),
                                l10n.text('languageSubtitle'),
                                _pickLanguage,
                                value: l10n.languageName(_settings.languageCode),
                              ),
                            ],
                          ),
                          _sectionLabel(l10n.text('accountSection')),
                          _tileCard(
                            children: [
                              _navRow(
                                l10n.text('changePassword'),
                                l10n.text('changePasswordSubtitle'),
                                _showChangePassword,
                              ),
                              Divider(
                                color: AppColors.mintIcon
                                    .withValues(alpha: 0.15),
                                thickness: 1,
                                height: 24,
                              ),
                              _switchRow(
                                l10n.text('twoFactorAuth'),
                                l10n.text('twoFactorSubtitle'),
                                _settings.twoFactorEnabled,
                                (v) async {
                                  await _settings.setTwoFactor(v);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        v
                                            ? l10n.text('twoFactorEnabled')
                                            : l10n.text('twoFactorDisabled'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          _sectionLabel(l10n.text('storeSection')),
                          _tileCard(
                            children: [
                              InkWell(
                                onTap: _pickCurrency,
                                borderRadius: BorderRadius.circular(8),
                                child: _valueRow(
                                  l10n.text('currency'),
                                  l10n.text('currencySubtitle'),
                                  _settings.currencyLabel,
                                ),
                              ),
                              Divider(
                                color: AppColors.mintIcon
                                    .withValues(alpha: 0.15),
                                thickness: 1,
                                height: 24,
                              ),
                              InkWell(
                                onTap: _editExchangeRate,
                                borderRadius: BorderRadius.circular(8),
                                child: _valueRow(
                                  l10n.text('exchangeRate'),
                                  _settings.currencyCode == 'PHP'
                                      ? l10n.text('baseCurrency')
                                      : '1 PHP → ${_settings.currencyCode}',
                                  _settings.currencyCode == 'PHP'
                                      ? '1.0'
                                      : _settings.exchangeRate.toString(),
                                ),
                              ),
                              Divider(
                                color: AppColors.mintIcon
                                    .withValues(alpha: 0.15),
                                thickness: 1,
                                height: 24,
                              ),
                              InkWell(
                                onTap: _editTaxRate,
                                borderRadius: BorderRadius.circular(8),
                                child: _valueRow(
                                  l10n.text('taxRate'),
                                  l10n.text('taxRateSubtitle'),
                                  '${_settings.taxRate.toStringAsFixed(0)}%',
                                ),
                              ),
                            ],
                          ),
                          _sectionLabel(l10n.text('notificationsSection')),
                          _tileCard(
                            children: [
                              _switchRow(
                                l10n.text('pushNotifications'),
                                _pushBusy
                                    ? l10n.text('updating')
                                    : l10n.text('pushSubtitle'),
                                _settings.pushEnabled,
                                _pushBusy ? null : _onPushChanged,
                              ),
                              Divider(
                                color: AppColors.mintIcon
                                    .withValues(alpha: 0.15),
                                thickness: 1,
                                height: 24,
                              ),
                              _switchRow(
                                l10n.text('emailAlerts'),
                                l10n.text('emailAlertsSubtitle'),
                                _settings.emailAlertsEnabled,
                                (v) => _settings.setEmailAlerts(v),
                              ),
                              Divider(
                                color: AppColors.mintIcon
                                    .withValues(alpha: 0.15),
                                thickness: 1,
                                height: 24,
                              ),
                              _switchRow(
                                l10n.text('lowStockAlerts'),
                                l10n.text('lowStockSubtitle'),
                                _settings.lowStockEnabled,
                                (v) => _settings.setLowStock(v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: TextButton.icon(
                              onPressed: _logout,
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFFF9E9E),
                                size: 18,
                              ),
                              label: Text(
                                l10n.text('logOut'),
                                style: const TextStyle(
                                  color: Color(0xFFFF9E9E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF381B1B).withValues(alpha: 0.85),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: AppColors.accentRed
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePassword() async {
    final l10n = context.l10n;
    final currentController = TextEditingController();
    final controller = TextEditingController();
    final confirm = TextEditingController();
    var saving = false;
    var obscure = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.darkGreenMid,
            title: Text(
              l10n.text('changePassword'),
              style: const TextStyle(color: AppColors.textWhite),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentController,
                  obscureText: obscure,
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    labelText: l10n.text('currentPassword'),
                    labelStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.fieldGreen.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    labelText: l10n.text('newPassword'),
                    labelStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.fieldGreen.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirm,
                  obscureText: obscure,
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    labelText: l10n.text('confirmPassword'),
                    labelStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.fieldGreen.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textFaint,
                        size: 20,
                      ),
                      onPressed: () =>
                          setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: Text(
                  l10n.text('cancel'),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final current = currentController.text;
                        final pass = controller.text;
                        if (current.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.text('enterCurrentPassword')),
                            ),
                          );
                          return;
                        }
                        if (pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.text('passwordLength'))),
                          );
                          return;
                        }
                        if (pass != confirm.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.text('passwordMismatch'))),
                          );
                          return;
                        }

                        final user = FirebaseAuth.instance.currentUser;
                        final email = user?.email;
                        if (user == null || email == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No signed-in user found.'),
                              backgroundColor: AppColors.accentRed,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => saving = true);
                        try {
                          final cred = EmailAuthProvider.credential(
                            email: email,
                            password: current,
                          );
                          await user.reauthenticateWithCredential(cred);
                          await user.updatePassword(pass);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Password updated.')),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() => saving = false);
                          if (!mounted) return;
                          final msg = switch (e.code) {
                            'wrong-password' ||
                            'invalid-credential' =>
                              'Current password is incorrect.',
                            'requires-recent-login' =>
                              'Please log out and log in again, then retry.',
                            'weak-password' => 'Choose a stronger password.',
                            _ => e.message ?? 'Failed to update password.',
                          };
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: AppColors.accentRed,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed: $e'),
                              backgroundColor: AppColors.accentRed,
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _tileCard({required List<Widget> children}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.darkGreenMid.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Column(children: children),
      );

  // FIX: added optional `value` named parameter so this can show the
  // currently-selected language (or any other value) next to the chevron.
  Widget _navRow(
    String title,
    String subtitle,
    VoidCallback onTap, {
    String? value,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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
              if (value != null) ...[
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.accentOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.accentOrange, size: 22),
            ],
          ),
        ),
      );

  Widget _valueRow(String title, String subtitle, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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
            Text(
              value,
              style: const TextStyle(
                color: AppColors.accentOrange,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.textFaint),
          ],
        ),
      );

  Widget _switchRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool>? onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.accentOrange,
              activeTrackColor: AppColors.accentOrange.withValues(alpha: 0.35),
            ),
          ],
        ),
      );
}