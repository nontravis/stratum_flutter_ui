import 'package:flutter/widgets.dart';

import 'smoke/semantics_id.dart';

/// Builds one fixture widget.
typedef FixtureBuilder = Widget Function(BuildContext context);

/// Every fixture the host app can open, keyed `<category>/<widget>`.
final Map<String, FixtureBuilder> fixtures = <String, FixtureBuilder>{
  'smoke/semantics_id': (context) => const SmokeSemanticsIdFixture(),
};
