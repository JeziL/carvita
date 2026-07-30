import 'package:flutter/widgets.dart';

import 'package:intl/intl.dart' show Bidi;

abstract final class BidiTextDirection {
  static TextDirection resolve(String text, {required TextDirection fallback}) {
    if (Bidi.startsWithRtl(text)) {
      return TextDirection.rtl;
    }
    if (Bidi.startsWithLtr(text)) {
      return TextDirection.ltr;
    }
    return fallback;
  }
}
