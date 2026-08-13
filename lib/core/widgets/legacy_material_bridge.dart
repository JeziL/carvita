import 'package:flutter/material.dart' as legacy_material;

import 'package:material_ui/material_ui.dart';

/// Hosts a legacy Material package widget inside the standalone Material tree.
///
/// Keep this adapter scoped to dependencies that have not migrated to
/// `package:material_ui` yet. Remove it once no runtime dependency needs the
/// bundled Material API.
class LegacyMaterialBridge extends StatelessWidget {
  const LegacyMaterialBridge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return MaterialUiCompatibilityBridge(
      child: legacy_material.Material(
        type: legacy_material.MaterialType.transparency,
        child: child,
      ),
    );
  }
}
