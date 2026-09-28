import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('fil')];
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String text(String key, {Map<String, String> values = const {}}) {
    var message = _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
    for (final value in values.entries) {
      message = message.replaceAll('{${value.key}}', value.value);
    }
    return message;
  }

  String languageName(String code) {
    return text(code == 'fil' ? 'languageTagalog' : 'languageEnglish');
  }

  static const _values = <String, Map<String, String>>{
    'en': {
      'navHome': 'Home',
      'navInventory': 'Inventory',
      'navScan': 'Scan',
      'navNotifications': 'Notifications',
      'navProfile': 'Profile',
      'settings': 'Settings',
      'languageSection': 'LANGUAGE',
      'language': 'Language',
      'languageSubtitle': 'Choose the app display language',
      'selectLanguage': 'Select language',
      'languageEnglish': 'English',
      'languageTagalog': 'Tagalog',
      'accountSection': 'ACCOUNT',
      'changePassword': 'Change Password',
      'changePasswordSubtitle': 'Update your login password',
      'twoFactorAuth': 'Two-Factor Auth',
      'twoFactorSubtitle': 'Reminder only — enroll MFA in Firebase Console',
      'twoFactorEnabled': 'Flag saved. Configure MFA in Firebase Auth to enforce it.',
      'twoFactorDisabled': 'Two-factor reminder turned off.',
      'storeSection': 'STORE',
      'currency': 'Currency',
      'currencySubtitle': 'Used across transactions',
      'selectCurrency': 'Select currency',
      'currencySet': 'Currency set to {currency}',
      'exchangeRate': 'Exchange Rate',
      'baseCurrency': 'Base currency (no conversion)',
      'exchangeRateTitle': 'Exchange rate (PHP → {currency})',
      'exchangeRatePrompt': '1 PHP equals how many {currency}?',
      'phpExchangeRate': 'Exchange rate is 1 when currency is PHP.',
      'validRate': 'Enter a valid rate greater than 0.',
      'rateSaved': 'Rate saved: 1 PHP = {rate} {currency}',
      'taxRate': 'Tax Rate (VAT)',
      'taxRateSubtitle': 'Applied to every sale',
      'taxRateTitle': 'Tax Rate (VAT %)',
      'percent': 'Percent',
      'validTaxRate': 'Enter a tax rate between 0 and 100.',
      'taxRateSet': 'Tax rate set to {rate}%',
      'notificationsSection': 'NOTIFICATIONS',
      'pushNotifications': 'Push Notifications',
      'updating': 'Updating…',
      'pushSubtitle': 'System alerts for orders & stock',
      'pushPermissionOff': 'Notification permission is off. Enable it in system settings.',
      'open': 'Open',
      'pushEnabled': 'Push notifications enabled.',
      'pushDisabled': 'Push notifications disabled.',
      'emailAlerts': 'Email Alerts',
      'emailAlertsSubtitle': 'Preference saved — email delivery needs backend',
      'lowStockAlerts': 'Low Stock Alerts',
      'lowStockSubtitle': 'Notify when stock is 5 or below',
      'logOut': 'Log Out',
      'logOutTitle': 'Log out?',
      'logOutMessage': 'You will need to sign in again to manage your store.',
      'cancel': 'Cancel',
      'save': 'Save',
      'currentPassword': 'Current password',
      'newPassword': 'New password',
      'confirmPassword': 'Confirm password',
      'enterCurrentPassword': 'Enter your current password.',
      'passwordLength': 'Password must be at least 6 characters.',
      'passwordMismatch': 'Passwords do not match.',
      'noSignedInUser': 'No signed-in user found.',
      'passwordUpdated': 'Password updated.',
      'currentPasswordIncorrect': 'Current password is incorrect.',
      'loginAgain': 'Please log out and log in again, then retry.',
      'strongerPassword': 'Choose a stronger password.',
      'passwordUpdateFailed': 'Failed to update password.',
      'failed': 'Failed: {error}',
      'profileTitle': 'Profile',
      'account': 'Account',
      'myStore': 'My Store',
      'manage': 'Manage',
      'edit': 'Edit',
      'orders': 'Orders',
      'ordersSubtitle': 'View and manage customer orders',
      'creditUtang': 'Credit / Utang',
      'creditUtangSubtitle': 'Manage unpaid customer debts',
      'settingsMenuSubtitle': 'Preferences and account options',
      'profileLoadError': 'Could not refresh profile. Showing saved details.',
    },
    'fil': {
      'navHome': 'Tahanan',
      'navInventory': 'Imbentaryo',
      'navScan': 'I-scan',
      'navNotifications': 'Mga Abiso',
      'navProfile': 'Profile',
      'settings': 'Mga Setting',
      'languageSection': 'WIKA',
      'language': 'Wika',
      'languageSubtitle': 'Piliin ang wikang gagamitin sa app',
      'selectLanguage': 'Pumili ng wika',
      'languageEnglish': 'English',
      'languageTagalog': 'Tagalog',
      'accountSection': 'ACCOUNT',
      'changePassword': 'Palitan ang Password',
      'changePasswordSubtitle': 'I-update ang password sa pag-login',
      'twoFactorAuth': 'Dalawang-Hakbang na Pagpapatunay',
      'twoFactorSubtitle': 'Paalala lang — i-set up ang MFA sa Firebase Console',
      'twoFactorEnabled': 'Nai-save ang setting. I-configure ang MFA sa Firebase Auth para maipatupad ito.',
      'twoFactorDisabled': 'Naka-off ang paalala sa dalawang hakbang.',
      'storeSection': 'TINDAHAN',
      'currency': 'Pera',
      'currencySubtitle': 'Ginagamit sa lahat ng transaksyon',
      'selectCurrency': 'Pumili ng pera',
      'currencySet': 'Nakatakda ang pera sa {currency}',
      'exchangeRate': 'Palitan ng Pera',
      'baseCurrency': 'Pangunahing pera (walang conversion)',
      'exchangeRateTitle': 'Palitan ng pera (PHP → {currency})',
      'exchangeRatePrompt': 'Ilang {currency} ang katumbas ng 1 PHP?',
      'phpExchangeRate': '1 ang palitan kapag PHP ang pera.',
      'validRate': 'Maglagay ng wastong halagang higit sa 0.',
      'rateSaved': 'Nai-save ang palitan: 1 PHP = {rate} {currency}',
      'taxRate': 'Buwis (VAT)',
      'taxRateSubtitle': 'Inilalapat sa bawat benta',
      'taxRateTitle': 'Buwis (VAT %)',
      'percent': 'Porsiyento',
      'validTaxRate': 'Maglagay ng buwis na nasa 0 hanggang 100.',
      'taxRateSet': 'Nakatakda ang buwis sa {rate}%',
      'notificationsSection': 'MGA ABISO',
      'pushNotifications': 'Push na Abiso',
      'updating': 'Ina-update…',
      'pushSubtitle': 'Mga alerto para sa order at stock',
      'pushPermissionOff': 'Naka-off ang pahintulot sa abiso. I-enable ito sa system settings.',
      'open': 'Buksan',
      'pushEnabled': 'Naka-enable ang push notifications.',
      'pushDisabled': 'Naka-disable ang push notifications.',
      'emailAlerts': 'Email na Alerto',
      'emailAlertsSubtitle': 'Nai-save ang preference — kailangan ng backend para sa email delivery',
      'lowStockAlerts': 'Alerto sa Mababang Stock',
      'lowStockSubtitle': 'Mag-abiso kapag 5 o mas mababa ang stock',
      'logOut': 'Mag-log Out',
      'logOutTitle': 'Mag-log out?',
      'logOutMessage': 'Kailangan mong mag-sign in muli upang pamahalaan ang iyong tindahan.',
      'cancel': 'Kanselahin',
      'save': 'I-save',
      'currentPassword': 'Kasalukuyang password',
      'newPassword': 'Bagong password',
      'confirmPassword': 'Kumpirmahin ang password',
      'enterCurrentPassword': 'Ilagay ang kasalukuyang password.',
      'passwordLength': 'Dapat hindi bababa sa 6 na character ang password.',
      'passwordMismatch': 'Hindi tugma ang mga password.',
      'noSignedInUser': 'Walang naka-sign in na user.',
      'passwordUpdated': 'Nai-update ang password.',
      'currentPasswordIncorrect': 'Mali ang kasalukuyang password.',
      'loginAgain': 'Mag-log out at mag-log in muli, pagkatapos ay subukan ulit.',
      'strongerPassword': 'Pumili ng mas malakas na password.',
      'passwordUpdateFailed': 'Hindi na-update ang password.',
      'failed': 'Nabigo: {error}',
      'profileTitle': 'Profile',
      'account': 'Account',
      'myStore': 'Tindahan Ko',
      'manage': 'Pamahalaan',
      'edit': 'I-edit',
      'orders': 'Mga Order',
      'ordersSubtitle': 'Tingnan at pamahalaan ang mga order ng customer',
      'creditUtang': 'Credit / Utang',
      'creditUtangSubtitle': 'Pamahalaan ang hindi pa nababayarang utang',
      'settingsMenuSubtitle': 'Mga preference at account option',
      'profileLoadError': 'Hindi na-refresh ang profile. Ipinapakita ang naka-save na detalye.',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((supported) => supported.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}