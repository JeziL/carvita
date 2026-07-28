import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:intl/intl.dart';

final class LocalizedNumberInput {
  const LocalizedNumberInput._();

  static double? parseDouble(String input, Locale locale) {
    final normalized = normalize(input, locale, allowDecimal: true);
    return normalized == null ? null : double.tryParse(normalized);
  }

  static int? parseInt(String input, Locale locale) {
    final normalized = normalize(input, locale, allowDecimal: false);
    return normalized == null ? null : int.tryParse(normalized);
  }

  static String? normalize(
    String input,
    Locale locale, {
    required bool allowDecimal,
  }) {
    final value = input.trim();
    if (value.isEmpty) return null;

    final decimalSeparator = NumberFormat.decimalPattern(
      locale.toLanguageTag(),
    ).symbols.DECIMAL_SEP;
    final buffer = StringBuffer();
    var hasDecimalSeparator = false;

    for (final rune in value.runes) {
      final digit = _asciiDigitForRune(rune);
      if (digit != null) {
        buffer.writeCharCode(digit);
        continue;
      }

      final character = String.fromCharCode(rune);
      final isDecimalSeparator =
          allowDecimal &&
          _isDecimalSeparator(character, localeSeparator: decimalSeparator);
      if (!isDecimalSeparator || hasDecimalSeparator) return null;
      hasDecimalSeparator = true;
      buffer.write('.');
    }

    final normalized = buffer.toString();
    if (normalized.isEmpty ||
        normalized.startsWith('.') ||
        normalized.endsWith('.')) {
      return null;
    }
    return normalized;
  }

  static int? _asciiDigitForRune(int rune) {
    const zeroDigits = <int>[
      0x0030, // ASCII
      0x0660, // Arabic-Indic
      0x06F0, // Eastern Arabic-Indic
      0x0966, // Devanagari
      0x09E6, // Bengali
      0x0E50, // Thai
      0xFF10, // Full-width
    ];
    for (final zeroDigit in zeroDigits) {
      final offset = rune - zeroDigit;
      if (offset >= 0 && offset <= 9) {
        return 0x0030 + offset;
      }
    }
    return null;
  }

  static bool _isDecimalSeparator(
    String character, {
    required String localeSeparator,
  }) {
    return character == '.' ||
        character == localeSeparator ||
        character == '\u066B';
  }
}

final class LocalizedNumberTextInputFormatter extends TextInputFormatter {
  LocalizedNumberTextInputFormatter.decimal(
    Locale locale, {
    this._maxFractionDigits,
  }) : _locale = locale,
       _allowDecimal = true;

  LocalizedNumberTextInputFormatter.integer(Locale locale)
    : _locale = locale,
      _allowDecimal = false,
      _maxFractionDigits = 0;

  final Locale _locale;
  final bool _allowDecimal;
  final int? _maxFractionDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || _isValidIntermediateValue(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }

  bool _isValidIntermediateValue(String value) {
    final decimalSeparator = NumberFormat.decimalPattern(
      _locale.toLanguageTag(),
    ).symbols.DECIMAL_SEP;
    var digitCount = 0;
    var decimalSeparatorCount = 0;
    var fractionDigitCount = 0;

    for (final rune in value.runes) {
      if (LocalizedNumberInput._asciiDigitForRune(rune) != null) {
        digitCount++;
        if (decimalSeparatorCount == 1) fractionDigitCount++;
        continue;
      }

      final character = String.fromCharCode(rune);
      final isDecimalSeparator =
          _allowDecimal &&
          LocalizedNumberInput._isDecimalSeparator(
            character,
            localeSeparator: decimalSeparator,
          );
      if (!isDecimalSeparator || digitCount == 0) return false;
      decimalSeparatorCount++;
      if (decimalSeparatorCount > 1) return false;
    }

    return _maxFractionDigits == null ||
        fractionDigitCount <= _maxFractionDigits;
  }
}
