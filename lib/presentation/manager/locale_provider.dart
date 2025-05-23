import 'package:flutter/material.dart';

import 'package:carvita/core/services/preferences_service.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/main.dart';

class LocaleProvider extends ChangeNotifier {
  final PreferencesService _preferencesService;
  Locale? _appLocale;
  String _mileageUnit = 'km';

  LocaleProvider(this._preferencesService) {
    _loadLocale();
  }

  Locale? get appLocale => _appLocale;

  String get mileageUnit => _mileageUnit;

  Future<void> _loadLocale() async {
    _appLocale = await _preferencesService.getAppLocale();
    _mileageUnit = await _preferencesService.getMileageUnit();
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    if (_appLocale == locale) return;

    _appLocale = locale;
    await _preferencesService.setAppLocale(locale);
    notifyListeners();
  }

  Future<void> setMileageUnit(String unit) async {
    if (_mileageUnit == unit) return;

    _mileageUnit = unit;
    await _preferencesService.setMileageUnit(unit);
    notifyListeners();
  }

  String getCurrentLocaleDisplayString(BuildContext context) {
    return getLocaleDisplayString(_appLocale, context);
  }

  static String getLocaleDisplayString(Locale? locale, BuildContext context) {
    if (locale == null) {
      return AppLocalizations.of(context)!.languageFollowSystem;
    }

    String localeName = locale.toLanguageTag();
    for (var lang in appSupportedLocales) {
      final lo = lang['locale'] as Locale;
      final name = lang['name'] as String;
      if (locale == lo) {
        localeName = name;
        break;
      }
      if (locale.languageCode == lo.languageCode &&
          locale.scriptCode == lo.scriptCode) {
        localeName = name;
        break;
      }
      if (locale.languageCode == lo.languageCode) {
        localeName = name;
        break;
      }
    }

    return localeName;
  }
}
