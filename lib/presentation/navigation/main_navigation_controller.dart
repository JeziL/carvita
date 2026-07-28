import 'package:flutter/widgets.dart';

/// Coordinates the persistent root tabs with navigation events that originate
/// outside the currently visible tab, such as shortcuts and notifications.
final class MainNavigationController extends ChangeNotifier {
  int _selectedIndex = 0;
  void Function(int index)? _selectionHandler;

  int get selectedIndex => _selectedIndex;

  void attach({
    required int initialIndex,
    required void Function(int index) onSelected,
  }) {
    _selectedIndex = initialIndex;
    _selectionHandler = onSelected;
  }

  void detach(void Function(int index) onSelected) {
    if (identical(_selectionHandler, onSelected)) {
      _selectionHandler = null;
    }
  }

  void selectTab(int index) {
    if (index < 0 || index > 3) return;
    if (index == _selectedIndex) return;
    _selectedIndex = index;
    _selectionHandler?.call(index);
    notifyListeners();
  }

  void revealRootTab(NavigatorState navigator, int index) {
    selectTab(index);
    navigator.popUntil((route) => route.isFirst);
  }
}
