import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';

import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:carvita/presentation/navigation/main_navigation_controller.dart';
import 'package:carvita/presentation/screens/common_widgets/main_bottom_navigation_bar.dart';

void main() {
  testWidgets('main navigation visual regression', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previousGoldenFileComparator = goldenFileComparator;
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse(
        'test/presentation/navigation/main_navigation_golden_test.dart',
      ),
      precisionTolerance: 0.001,
    );
    addTearDown(() => goldenFileComparator = previousGoldenFileComparator);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MainNavigationController(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: const Scaffold(
            body: ColoredBox(color: Color(0xfff5f7fa)),
            bottomNavigationBar: MainBottomNavigationBar(currentIndex: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/main_bottom_navigation.png'),
    );
  });
}

final class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(
         0 <= precisionTolerance && precisionTolerance <= 1,
         'precisionTolerance must be between 0 and 1',
       ),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _precisionTolerance) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
