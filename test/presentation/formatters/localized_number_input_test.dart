import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/presentation/formatters/localized_number_input.dart';

void main() {
  test('parses locale digits and decimal separators', () {
    expect(
      LocalizedNumberInput.parseDouble('١٢٣٫٤', const Locale('ar')),
      123.4,
    );
    expect(
      LocalizedNumberInput.parseDouble('123,4', const Locale('de')),
      123.4,
    );
    expect(
      LocalizedNumberInput.parseDouble('123.4', const Locale('de')),
      123.4,
    );
    expect(LocalizedNumberInput.parseInt('１２３', const Locale('ja')), 123);
  });

  test('rejects mixed separators, grouping, and fractional integers', () {
    expect(
      LocalizedNumberInput.parseDouble('1.234,5', const Locale('de')),
      isNull,
    );
    expect(
      LocalizedNumberInput.parseDouble('1,234,5', const Locale('de')),
      isNull,
    );
    expect(LocalizedNumberInput.parseInt('12,3', const Locale('de')), isNull);
  });

  test(
    'decimal formatter preserves valid local input and rejects overflow',
    () {
      final formatter = LocalizedNumberTextInputFormatter.decimal(
        const Locale('ar'),
        maxFractionDigits: 1,
      );
      const empty = TextEditingValue.empty;
      const valid = TextEditingValue(text: '١٢٫٣');
      const tooPrecise = TextEditingValue(text: '١٢٫٣٤');

      expect(formatter.formatEditUpdate(empty, valid), valid);
      expect(formatter.formatEditUpdate(valid, tooPrecise), valid);
    },
  );

  test('all supported locales accept normalized ASCII decimal input', () {
    const locales = [
      Locale('ar'),
      Locale('de'),
      Locale('en'),
      Locale('es'),
      Locale('fr'),
      Locale('it'),
      Locale('ja'),
      Locale('ko'),
      Locale('pt'),
      Locale('ru'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ];

    for (final locale in locales) {
      expect(
        LocalizedNumberInput.parseDouble('123.4', locale),
        123.4,
        reason: locale.toLanguageTag(),
      );
    }
  });
}
