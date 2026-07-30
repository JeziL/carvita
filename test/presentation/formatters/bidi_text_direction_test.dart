import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carvita/presentation/formatters/bidi_text_direction.dart';

void main() {
  group('BidiTextDirection', () {
    test('uses RTL for Persian plate numbers with mixed text and digits', () {
      expect(
        BidiTextDirection.resolve('۱۲ ۳۴۵ الف ۶۷', fallback: TextDirection.ltr),
        TextDirection.rtl,
      );
    });

    test('uses LTR for Latin plate numbers in an RTL interface', () {
      expect(
        BidiTextDirection.resolve('ABC 123', fallback: TextDirection.rtl),
        TextDirection.ltr,
      );
    });

    test('uses the interface direction for neutral text', () {
      expect(
        BidiTextDirection.resolve('--', fallback: TextDirection.rtl),
        TextDirection.rtl,
      );
    });
  });
}
