import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted store settings (currency, tax, exchange rate, notification toggles).
///
/// Money amounts in the app are stored in PHP. [exchangeRate] converts PHP →
/// the selected display currency (1.0 when currency is PHP).
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _kCurrency = 'settings_currency';
  static const _kTaxRate = 'settings_tax_rate';
  static const _kExchangeRate = 'settings_exchange_rate';
  static const _kPush = 'settings_push';
  static const _kEmail = 'settings_email_alerts';
  static const _kLowStock = 'settings_low_stock';
  static const _kTwoFactor = 'settings_two_factor';
  static const _kLanguage = 'settings_language';

  String _currencyCode = 'PHP';
  double _taxRate = 12.0;
  /// PHP → selected currency (e.g. 0.018 for USD). Always 1 when currency is PHP.
  double _exchangeRate = 1.0;
  bool _push = true;
  bool _emailAlerts = false;
  bool _lowStock = true;
  bool _twoFactor = false;
  String _languageCode = 'en';
  bool _loaded = false;

  String get currencyCode => _currencyCode;
  double get taxRate => _taxRate;
  double get exchangeRate => _exchangeRate;
  bool get pushEnabled => _push;
  bool get emailAlertsEnabled => _emailAlerts;
  bool get lowStockEnabled => _lowStock;
  bool get twoFactorEnabled => _twoFactor;
  String get languageCode => _languageCode;
  bool get isLoaded => _loaded;

  String get currencySymbol {
    switch (_currencyCode) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'JPY':
        return '¥';
      case 'PHP':
      default:
        return '₱';
    }
  }

  String get currencyLabel {
    switch (_currencyCode) {
      case 'USD':
        return '\$ USD';
      case 'EUR':
        return '€ EUR';
      case 'JPY':
        return '¥ JPY';
      case 'PHP':
      default:
        return '₱ PHP';
    }
  }

  /// Default PHP→currency rates used when switching currency if no custom rate.
  static double defaultRateFor(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
        return 0.018;
      case 'EUR':
        return 0.016;
      case 'JPY':
        return 2.7;
      case 'PHP':
      default:
        return 1.0;
    }
  }

  static String _normalizeLanguage(String? code) {
    return code?.toLowerCase() == 'fil' ? 'fil' : 'en';
  }

  /// Convert a PHP amount to the selected display currency.
  double convertFromPhp(num amountPhp) {
    final rate = _currencyCode == 'PHP' ? 1.0 : _exchangeRate;
    return amountPhp.toDouble() * (rate <= 0 ? 1.0 : rate);
  }

  /// Format a PHP-stored amount using the selected currency + exchange rate.
  String formatMoney(num amountPhp, {int decimals = 2}) {
    final converted = convertFromPhp(amountPhp);
    final places = _currencyCode == 'JPY' ? 0 : decimals;
    return '$currencySymbol${converted.toStringAsFixed(places)}';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currencyCode = prefs.getString(_kCurrency) ?? 'PHP';
    _taxRate = prefs.getDouble(_kTaxRate) ?? 12.0;
    _exchangeRate = prefs.getDouble(_kExchangeRate) ?? defaultRateFor(_currencyCode);
    _push = prefs.getBool(_kPush) ?? true;
    _emailAlerts = prefs.getBool(_kEmail) ?? false;
    _lowStock = prefs.getBool(_kLowStock) ?? true;
    _twoFactor = prefs.getBool(_kTwoFactor) ?? false;
    _languageCode = _normalizeLanguage(prefs.getString(_kLanguage));

    // Prefer Firestore user settings when logged in.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();
        final settings = data?['settings'];
        if (settings is Map) {
          _currencyCode =
              (settings['currency'] as String?)?.toUpperCase() ?? _currencyCode;
          _taxRate = (settings['taxRate'] as num?)?.toDouble() ?? _taxRate;
          _exchangeRate =
              (settings['exchangeRate'] as num?)?.toDouble() ?? _exchangeRate;
          _push = settings['push'] as bool? ?? _push;
          _emailAlerts = settings['emailAlerts'] as bool? ?? _emailAlerts;
          _lowStock = settings['lowStock'] as bool? ?? _lowStock;
          _twoFactor = settings['twoFactor'] as bool? ?? _twoFactor;
          _languageCode =
              _normalizeLanguage(settings['language'] as String? ?? _languageCode);
        }
      } catch (e) {
        debugPrint('[SettingsStore] Firestore load failed: $e');
      }
    }

    if (_currencyCode == 'PHP') _exchangeRate = 1.0;
    _loaded = true;
    notifyListeners();
  }

  /// Call after login so Firestore-backed settings replace prefs defaults.
  Future<void> reloadForCurrentUser() => load();

  Future<void> setCurrency(String code) async {
    final next = code.toUpperCase();
    _currencyCode = next;
    if (next == 'PHP') {
      _exchangeRate = 1.0;
    } else if (_exchangeRate == 1.0 || _exchangeRate <= 0) {
      _exchangeRate = defaultRateFor(next);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> setExchangeRate(double rate) async {
    if (_currencyCode == 'PHP') {
      _exchangeRate = 1.0;
    } else {
      _exchangeRate = rate <= 0 ? defaultRateFor(_currencyCode) : rate;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> setTaxRate(double rate) async {
    _taxRate = rate.clamp(0, 100);
    notifyListeners();
    await _persist();
  }

  Future<void> setPush(bool value) async {
    _push = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setEmailAlerts(bool value) async {
    _emailAlerts = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setLowStock(bool value) async {
    _lowStock = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setTwoFactor(bool value) async {
    _twoFactor = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setLanguage(String code) async {
    _languageCode = _normalizeLanguage(code);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrency, _currencyCode);
    await prefs.setDouble(_kTaxRate, _taxRate);
    await prefs.setDouble(_kExchangeRate, _exchangeRate);
    await prefs.setBool(_kPush, _push);
    await prefs.setBool(_kEmail, _emailAlerts);
    await prefs.setBool(_kLowStock, _lowStock);
    await prefs.setBool(_kTwoFactor, _twoFactor);
    await prefs.setString(_kLanguage, _languageCode);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'settings': {
          'currency': _currencyCode,
          'taxRate': _taxRate,
          'exchangeRate': _exchangeRate,
          'push': _push,
          'emailAlerts': _emailAlerts,
          'lowStock': _lowStock,
          'twoFactor': _twoFactor,
          'language': _languageCode,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[SettingsStore] Firestore save failed: $e');
    }
  }
}
