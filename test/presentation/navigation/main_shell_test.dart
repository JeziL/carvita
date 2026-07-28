import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';

import 'package:carvita/presentation/navigation/main_navigation_controller.dart';
import 'package:carvita/presentation/navigation/main_shell.dart';

void main() {
  testWidgets('tab switch preserves state and Android back returns home', (
    tester,
  ) async {
    final controller = MainNavigationController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: MainShell(
            tabs: [
              const _CounterTab(name: 'dashboard'),
              const _CounterTab(name: 'vehicles'),
              const _CounterTab(name: 'upcoming'),
              const _CounterTab(name: 'settings'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('dashboard-increment')));
    await tester.pump();
    expect(find.text('dashboard:1'), findsOneWidget);

    controller.selectTab(1);
    await tester.pump();
    expect(find.text('vehicles:0'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(controller.selectedIndex, 0);
    expect(find.text('dashboard:1'), findsOneWidget);
  });

  testWidgets('scroll position survives switching between tabs', (
    tester,
  ) async {
    final controller = MainNavigationController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: MainShell(
            initialIndex: 1,
            tabs: [
              const SizedBox(),
              const _ScrollableTab(),
              const SizedBox(),
              const SizedBox(),
            ],
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('vehicle-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('vehicle-scroll')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;
    expect(before, greaterThan(0));

    controller.selectTab(2);
    await tester.pump();
    controller.selectTab(1);
    await tester.pump();

    final after = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('vehicle-scroll')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;
    expect(after, before);
  });
}

class _CounterTab extends StatefulWidget {
  const _CounterTab({required this.name});

  final String name;

  @override
  State<_CounterTab> createState() => _CounterTabState();
}

class _CounterTabState extends State<_CounterTab> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('${widget.name}:$count'),
          FilledButton(
            key: ValueKey('${widget.name}-increment'),
            onPressed: () => setState(() => count++),
            child: const Text('increment'),
          ),
        ],
      ),
    );
  }
}

class _ScrollableTab extends StatelessWidget {
  const _ScrollableTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        key: const ValueKey('vehicle-scroll'),
        itemCount: 100,
        itemBuilder: (_, index) =>
            SizedBox(height: 50, child: Text('vehicle $index')),
      ),
    );
  }
}
