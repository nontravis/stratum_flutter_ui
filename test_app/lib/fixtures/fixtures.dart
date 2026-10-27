import 'package:flutter/widgets.dart';

import 'common/focus_builder.dart';
import 'common/ink_well.dart';
import 'common/keyboard_visibility_scope.dart';
import 'common/modal_layout.dart';
import 'common/page_drawer.dart';
import 'common/page_drawer_in_safe_area.dart';
import 'common/page_layout.dart';
import 'common/page_layout_loading.dart';
import 'common/reorderable_list_view_layout.dart';
import 'common/splash_screen.dart';
import 'common/split_layout.dart';
import 'common/web_view.dart';
import 'feedback/toast_shortcut.dart';
import 'feedback/update_gate.dart';
import 'smoke/semantics_id.dart';
import 'themes/system_style.dart';

/// Builds one fixture widget.
typedef FixtureBuilder = Widget Function(BuildContext context);

/// One registry entry: the fixture's [builder] and how the host page treats
/// the system-bar insets.
///
/// An edge-to-edge fixture draws under the system bars: the host adds no
/// safe-area padding, because the fixture pads its own slots by the insets
/// through `PageLayout.safeArea` or proves the bar styles over content that
/// runs to the screen edge. Every other fixture sits inside the safe area,
/// so no edge-to-edge window hides a row under a bar.
class FixtureEntry {
  const FixtureEntry({required this.builder, this.edgeToEdge = false});

  /// Builds the fixture widget.
  final FixtureBuilder builder;

  /// Whether the host page skips its `SafeArea`, letting the fixture handle
  /// the insets itself.
  final bool edgeToEdge;
}

/// Every fixture the host app can open, keyed `<category>/<widget>`.
///
/// A fixture that builds a `PageLayout` registers `edgeToEdge: true`:
/// `PageLayout` pads its own slots by the insets, and a host `SafeArea` would
/// shrink its box below the screen. `common/page_drawer_in_safe_area` keeps
/// the host `SafeArea` on purpose: it proves a drawer stays inside that
/// smaller box (FO-06 US-19 FR-04 E09).
final Map<String, FixtureEntry> fixtures = <String, FixtureEntry>{
  'common/focus_builder': FixtureEntry(
    builder: (context) => const FocusBuilderFixture(),
  ),
  'common/ink_well': FixtureEntry(builder: (context) => const InkWellFixture()),
  'common/keyboard_visibility_scope': FixtureEntry(
    builder: (context) => const KeyboardVisibilityScopeFixture(),
  ),
  'common/modal_layout': FixtureEntry(
    builder: (context) => const ModalLayoutFixture(),
  ),
  'common/page_drawer': FixtureEntry(
    builder: (context) => const PageDrawerFixture(),
    edgeToEdge: true,
  ),
  'common/page_drawer_in_safe_area': FixtureEntry(
    builder: (context) => const PageDrawerInSafeAreaFixture(),
    edgeToEdge: false,
  ),
  'common/page_layout': FixtureEntry(
    builder: (context) => const PageLayoutFixture(),
    edgeToEdge: true,
  ),
  'common/page_layout_loading': FixtureEntry(
    builder: (context) => const PageLayoutLoadingFixture(),
    edgeToEdge: true,
  ),
  'common/reorderable_list_view_layout': FixtureEntry(
    builder: (context) => const ReorderableListViewLayoutFixture(),
  ),
  'common/splash_screen': FixtureEntry(
    builder: (context) => const SplashScreenFixture(),
  ),
  'common/split_layout': FixtureEntry(
    builder: (context) => const SplitLayoutFixture(),
  ),
  'common/web_view': FixtureEntry(builder: (context) => const WebViewFixture()),
  'feedback/toast_shortcut': FixtureEntry(
    builder: (context) => const ToastShortcutFixture(),
  ),
  'feedback/update_gate': FixtureEntry(
    builder: (context) => const UpdateGateFixture(),
  ),
  'smoke/semantics_id': FixtureEntry(
    builder: (context) => const SmokeSemanticsIdFixture(),
  ),
  'themes/system_style': FixtureEntry(
    builder: (context) => const SystemStyleFixture(),
    edgeToEdge: true,
  ),
};
