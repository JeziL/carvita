import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:carvita/core/services/preferences_service.dart';

class LocaleProvider extends ChangeNotifier {
  final PreferencesService _preferencesService;
  Locale? _appLocale;

  LocaleProvider(this._preferencesService) {
    _loadLocale();
  }

  Locale? get appLocale => _appLocale;

  Future<void> _loadLocale() async {
    _appLocale = await _preferencesService.getAppLocale();
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    if (_appLocale == locale) return;

    _appLocale = locale;
    await _preferencesService.setAppLocale(locale);
    notifyListeners();
  }

  String getCurrentLocaleDisplayString(BuildContext context) {
    return getLocaleDisplayString(_appLocale, context);
  }

  static String getLocaleDisplayString(Locale? locale, BuildContext context) {
    if (locale == null) {
      return AppLocalizations.of(context)!.languageFollowSystem;
    }
    switch (locale.languageCode) {
      case 'en':
        return "English";
      case 'zh':
        if (locale.scriptCode == 'Hans') return "简体中文";
        return "中文";
      default:
        return locale.toLanguageTag();
    }
  }
}
