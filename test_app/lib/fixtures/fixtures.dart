import 'package:flutter/widgets.dart';

import 'common/ink_well.dart';
import 'common/modal_layout.dart';
import 'common/page_layout.dart';
import 'common/reorderable_list_view_layout.dart';
import 'common/split_layout.dart';
import 'smoke/semantics_id.dart';
import 'themes/system_style.dart';

/// Builds one fixture widget.
typedef FixtureBuilder = Widget Function(BuildContext context);

/// Every fixture the host app can open, keyed `<category>/<widget>`.
final Map<String, FixtureBuilder> fixtures = <String, FixtureBuilder>{
  'common/ink_well': (context) => const InkWellFixture(),
  'common/modal_layout': (context) => const ModalLayoutFixture(),
  'common/page_layout': (context) => const PageLayoutFixture(),
  'common/reorderable_list_view_layout': (context) =>
      const ReorderableListViewLayoutFixture(),
  'common/split_layout': (context) => const SplitLayoutFixture(),
  'smoke/semantics_id': (context) => const SmokeSemanticsIdFixture(),
  'themes/system_style': (context) => const SystemStyleFixture(),
};
