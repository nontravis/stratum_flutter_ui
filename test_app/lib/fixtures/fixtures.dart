import 'package:flutter/widgets.dart';

import 'common/focus_builder.dart';
import 'common/ink_well.dart';
import 'common/modal_layout.dart';
import 'common/page_drawer.dart';
import 'common/page_layout.dart';
import 'common/page_layout_loading.dart';
import 'common/reorderable_list_view_layout.dart';
import 'common/split_layout.dart';
import 'common/web_view.dart';
import 'smoke/semantics_id.dart';
import 'themes/system_style.dart';

/// Builds one fixture widget.
typedef FixtureBuilder = Widget Function(BuildContext context);

/// Every fixture the host app can open, keyed `<category>/<widget>`.
final Map<String, FixtureBuilder> fixtures = <String, FixtureBuilder>{
  'common/focus_builder': (context) => const FocusBuilderFixture(),
  'common/ink_well': (context) => const InkWellFixture(),
  'common/modal_layout': (context) => const ModalLayoutFixture(),
  'common/page_drawer': (context) => const PageDrawerFixture(),
  'common/page_layout': (context) => const PageLayoutFixture(),
  'common/page_layout_loading': (context) => const PageLayoutLoadingFixture(),
  'common/reorderable_list_view_layout': (context) =>
      const ReorderableListViewLayoutFixture(),
  'common/split_layout': (context) => const SplitLayoutFixture(),
  'common/web_view': (context) => const WebViewFixture(),
  'smoke/semantics_id': (context) => const SmokeSemanticsIdFixture(),
  'themes/system_style': (context) => const SystemStyleFixture(),
};

/// Fixture ids that draw under the system bars on purpose, so the host adds
/// no safe-area padding around them.
///
/// `common/page_layout` pads its own slots by the insets through
/// `PageLayout.safeArea`, and `themes/system_style` proves the bar styles over
/// content that runs to the screen edge. Every other fixture sits inside the
/// safe area, so no edge-to-edge window hides a row under a bar.
const Set<String> edgeToEdgeFixtures = <String>{
  'common/page_layout',
  'themes/system_style',
};
